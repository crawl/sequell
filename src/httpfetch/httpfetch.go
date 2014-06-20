package httpfetch

import (
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const DefaultUserAgent = "httpfetch/1.0"

var quiet = false

var httpTimeout = time.Duration(10 * time.Second)
var httpTransport = http.Transport{Dial: dialTimeout}
var httpClient = &http.Client{Transport: &httpTransport}
var userAgent = DefaultUserAgent
var MaxConcurrentRequestsPerHost = 5

var logWriter = CreateLogger()

const O_APPEND = os.O_WRONLY | os.O_APPEND | os.O_CREATE

func SetLogWriter(writer io.Writer) {
	logWriter.SetWriter(writer)
}

type unbufferedWriter struct {
	file *os.File
}

func (uw unbufferedWriter) Write(b []byte) (n int, err error) {
	n, err = uw.file.Write(b)
	if err != nil {
		_ = uw.file.Sync()
	}
	return
}

func SetLogFile(file *os.File) {
	SetLogWriter(unbufferedWriter{file: file})
}

func Logf(format string, rest ...interface{}) {
	fmt.Fprintf(logWriter, format, rest...)
}

func dialTimeout(network, addr string) (net.Conn, error) {
	return net.DialTimeout(network, addr, httpTimeout)
}

func SetUserAgent(agent string) {
	userAgent = agent
}

func UserAgent() string {
	return userAgent
}

func SetQuiet(q bool) {
	quiet = q
}

func Quiet() bool {
	return quiet
}

func GetConcurrentRequestCount(count int) int {
	if count > MaxConcurrentRequestsPerHost {
		return MaxConcurrentRequestsPerHost
	}
	return count
}

type Headers map[string]string

type HttpError struct {
	StatusCode int
	Response   *http.Response
}

func (err *HttpError) Error() string {
	req := err.Response.Request
	return fmt.Sprint(req.Method, " ", req.URL, " failed: ", err.StatusCode)
}

type FetchRequest struct {
	Url      string
	Filename string

	// Don't try to resume downloads if this is set.
	FullDownload   bool
	RequestHeaders Headers
}

func (req *FetchRequest) Host() (string, error) {
	reqUrl, err := url.Parse(req.Url)
	if err != nil {
		return "", err
	}
	return reqUrl.Host, nil
}

func (req *FetchRequest) String() string {
	return fmt.Sprint(req.Url, " -> ", req.Filename)
}

type FetchResult struct {
	Req          *FetchRequest
	Err          error
	DownloadSize int64
}

func fetchError(req *FetchRequest, err error) *FetchResult {
	return &FetchResult{req, err, 0}
}

func (headers Headers) AddHeaders(h *http.Header) {
	for header, value := range headers {
		h.Add(header, value)
	}
}

func (headers Headers) Copy() Headers {
	res := make(Headers)
	for k, v := range headers {
		res[k] = v
	}
	return res
}

func HeadersWith(headers Headers, newHeader, newValue string) Headers {
	headerCopy := headers.Copy()
	headerCopy[newHeader] = newValue
	return headerCopy
}

func FileGetResponse(url string, headers Headers) (*http.Response, error) {
	request, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	request.Header.Add("User-Agent", UserAgent())
	if headers != nil {
		headers.AddHeaders(&request.Header)
	}
	resp, err := httpClient.Do(request)
	if err != nil {
		return resp, err
	}
	if resp.StatusCode >= 400 {
		return nil, &HttpError{resp.StatusCode, resp}
	}
	return resp, err
}

func FetchFile(req *FetchRequest, complete chan<- *FetchResult) {
	Logf("FetchFile[%s] -> %s (full download: %v)", req.Url, req.Filename,
		req.FullDownload)
	if !req.FullDownload {
		finf, err := os.Stat(req.Filename)
		if err == nil && finf != nil && finf.Size() > 0 {
			Logf("FetchFile[%s]: resuming download for %s",
				req.Url, req.Filename)
			ResumeFileDownload(req, complete)
			return
		}
	}
	Logf("FetchFile[%s]: new file download %s", req.Url, req.Filename)
	NewFileDownload(req, complete)
}

func fileResumeHeaders(req *FetchRequest, file *os.File) (Headers, int64) {
	headers := req.RequestHeaders
	finf, err := file.Stat()
	resumePoint := int64(0)
	if err == nil && finf != nil {
		resumePoint = finf.Size()
		if headers == nil {
			headers = Headers{}
		} else {
			headers = headers.Copy()
		}
		headers["Range"] = fmt.Sprintf("bytes=%d-", resumePoint)
		headers["Accept-Encoding"] = ""
	}
	return headers, resumePoint
}

func ResumeFileDownload(req *FetchRequest, complete chan<- *FetchResult) {
	Logf("ResumeFileDownload[%s] -> %s", req.Url, req.Filename)
	var err error
	handleError := func() {
		if err != nil && !quiet {
			log.Println("Download of", req, "failed:", err)
		}
		Logf("handleError[%s] -> %s, err: %v", req.Url, req.Filename, err)
		complete <- fetchError(req, err)
	}

	if !quiet {
		log.Println("ResumeFileDownload", req)
	}
	file, err := os.OpenFile(req.Filename, O_APPEND, 0644)
	if err != nil {
		handleError()
		return
	}
	defer file.Close()

	headers, resumePoint := fileResumeHeaders(req, file)
	resp, err := FileGetResponse(req.Url, headers)

	var copied int64 = 0
	if err != nil {
		httpErr, _ := err.(*HttpError)
		if httpErr == nil || httpErr.StatusCode != http.StatusRequestedRangeNotSatisfiable {
			handleError()
			return
		}
		err = nil
	} else {
		defer resp.Body.Close()
		Logf("ResumeFileDownload[%s]: Copying bytes to %s from response",
			req.Url, req.Filename)
		copied, err = io.Copy(file, resp.Body)
	}
	if !quiet {
		log.Printf("[DONE:%d] ResumeFileDownload (at %d) %s\n", copied, resumePoint, req)
	}
	Logf("ResumeFileDownload[%s] -> %s: completed, bytes copied: %v, err: %v",
		req.Url, req.Filename, copied, err)
	complete <- &FetchResult{req, err, copied}
}

func NewFileDownload(req *FetchRequest, complete chan<- *FetchResult) {
	Logf("NewFileDownload[%s] -> %s", req.Url, req.Filename)
	if !quiet {
		log.Println("NewFileDownload ", req)
	}
	resp, err := FileGetResponse(req.Url, req.RequestHeaders)
	if err != nil {
		Logf("NewFileDownload[%s] -> %s: error: %v (http)", req.Url, req.Filename, err)
		complete <- fetchError(req, err)
		return
	}
	defer resp.Body.Close()

	file, err := os.Create(req.Filename)
	if err != nil {
		Logf("NewFileDownload[%s] -> %s: error: %v (fopen)", req.Url, req.Filename, err)
		complete <- fetchError(req, err)
		return
	}
	defer file.Close()

	Logf("NewFileDownload[%s] -> %s: copying bytes", req.Url, req.Filename)
	copied, err := io.Copy(file, resp.Body)
	if !quiet {
		log.Printf("[DONE:%d] NewFileDownload %s\n", copied, req)
	}
	Logf("NewFileDownload[%s] -> %s: completed copy:%v, err:%v", req.Url, req.Filename, copied, err)
	complete <- &FetchResult{req, err, copied}
}

func groupFetchRequestsByHost(requests []*FetchRequest) map[string][]*FetchRequest {
	grouped := make(map[string][]*FetchRequest)
	for _, req := range requests {
		reqHost, _ := req.Host()
		grouped[reqHost] = append(grouped[reqHost], req)
	}
	return grouped
}

func ParallelFetch(requests ...*FetchRequest) []*FetchResult {
	Logf("ParallelFetch: %d files", len(requests))

	completion := make(chan *FetchResult)
	defer close(completion)

	runHostRequests := func(host string, reqs []*FetchRequest) {
		reqChan := make(chan *FetchRequest, len(reqs))
		for _, req := range reqs {
			reqChan <- req
		}
		close(reqChan)
		nRoutines := GetConcurrentRequestCount(len(reqs))
		Logf("runHostRequests[%s]: spinning up %d fetch routines for %d URLs",
			host, nRoutines, len(reqs))
		for i := 0; i < nRoutines; i++ {
			go func() {
				for req := range reqChan {
					FetchFile(req, completion)
				}
			}()
		}
	}
	for host, requests := range groupFetchRequestsByHost(requests) {
		Logf("runHostRequests: %s (%d requests)", host, len(requests))
		runHostRequests(host, requests)
	}

	nrequests := len(requests)
	Logf("ParallelFetch: waiting for %d requests to complete", nrequests)
	results := make([]*FetchResult, nrequests)
	for i := 0; i < nrequests; i++ {
		results[i] = <-completion
		Logf("ParallelFetch: completed: %s", results[i])
	}
	Logf("ParallelFetch: all done: %d requests completed", nrequests)
	return results
}

func UrlFilename(url string) (string, error) {
	for {
		if len(url) == 0 {
			return "", errors.New(fmt.Sprintf("No filename for empty URL"))
		}

		slashIndex := strings.LastIndex(url, "/")
		if slashIndex == -1 {
			return "", errors.New(fmt.Sprint("Cannot determine URL filename from ", url))
		}

		filename := url[slashIndex+1:]
		if len(filename) == 0 {
			url = url[:len(url)-1]
			continue
		}
		return filename, nil
	}
}
