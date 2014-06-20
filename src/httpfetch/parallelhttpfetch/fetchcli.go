package main

import (
	"fmt"
	"github.com/droundy/goopt"
	"httpfetch"
	"os"
	"runtime"
	"strings"
)

func usage() {
	fmt.Println("Usage:", os.Args[0], "URLs")
	os.Exit(1)
}

func die(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

func createUrlRequest(url string) (*httpfetch.FetchRequest, error) {
	var filename string
	var err error

	gtPos := strings.LastIndex(url, ">")
	if gtPos != -1 {
		filename = url[gtPos+1:]
		url = url[:gtPos]
	} else {
		filename, err = httpfetch.UrlFilename(url)
		if err != nil {
			return nil, err
		}
	}

	return &httpfetch.FetchRequest{
		Url:            url,
		Filename:       filename,
		FullDownload:   false,
		RequestHeaders: nil,
	}, nil
}

func createUrlRequests(urls []string) (requests []*httpfetch.FetchRequest, err error) {
	requests = make([]*httpfetch.FetchRequest, len(urls))
	for i, url := range urls {
		requests[i], err = createUrlRequest(url)
		if err != nil {
			return nil, err
		}
	}
	return requests, nil
}

func reportDownloadResults(results []*httpfetch.FetchResult) {
	for _, result := range results {
		req := result.Req
		if result.Err != nil {
			fmt.Fprintln(os.Stderr, "Download of", req, "failed:", result.Err)
		} else if !httpfetch.Quiet() {
			fmt.Fprintln(os.Stderr, "Downloaded", req, "(",
				result.DownloadSize, "bytes)")
		}
	}
}

const logfile = "http-fetch.log"

func main() {
	file, err := os.Create(logfile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Couldn't open logfile %s: %v", logfile, err)
		os.Exit(1)
	}
	httpfetch.SetLogFile(file)

	httpfetch.Logf("Setting max procs to %d", runtime.NumCPU())
	runtime.GOMAXPROCS(runtime.NumCPU())

	quiet := goopt.Flag([]string{"-q", "--quiet"}, nil,
		"Quiet (log only errors)", "")
	userAgent := goopt.String([]string{"--user-agent"}, "", "user agent string")
	goopt.Parse(nil)

	httpfetch.Logf("Setting quiet to %v", *quiet)
	httpfetch.SetQuiet(*quiet)
	if userAgent != nil && len(*userAgent) > 0 {
		httpfetch.Logf("Setting user agent to %s", *userAgent)
		httpfetch.SetUserAgent(*userAgent)
	}

	args := goopt.Args
	if len(args) <= 0 {
		httpfetch.Logf("Insufficient args, exiting")
		usage()
	}

	reqs, err := createUrlRequests(args)
	httpfetch.Logf("Created %d URL requests", len(reqs))
	if err != nil {
		die(err)
	}

	httpfetch.Logf("Fetching %d URL requests", len(reqs))
	results := httpfetch.ParallelFetch(reqs...)
	httpfetch.Logf("Reporting %d URL results", len(results))
	reportDownloadResults(results)
	httpfetch.Logf("All done, exiting")
}
