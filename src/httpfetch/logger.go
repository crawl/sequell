package httpfetch

import (
	"fmt"
	"io"
)

type Logger interface {
	SetWriter(writer io.Writer)
	io.Writer
	io.Closer
}

type loggerImpl struct {
	writer    io.Writer
	logMsg    chan func() string
	writerSet chan io.Writer
}

func (l *loggerImpl) SetWriter(writer io.Writer) {
	l.writerSet <- writer
}

func (l *loggerImpl) Write(b []byte) (int, error) {
	bcopy := make([]byte, len(b), len(b))
	copy(bcopy, b)
	l.logMsg <- func() string { return string(bcopy) }
	return len(b), nil
}

func (l *loggerImpl) Close() error {
	if l.logMsg != nil {
		close(l.logMsg)
		l.logMsg = nil
	}
	return nil
}

func CreateLogger() Logger {
	res := &loggerImpl{
		logMsg:    make(chan func() string),
		writerSet: make(chan io.Writer),
	}
	go logger(res)
	return res
}

func logger(l *loggerImpl) {
	for {
		select {
		case writer := <-l.writerSet:
			l.writer = writer
		case msgf, ok := <-l.logMsg:
			if !ok {
				return
			}
			if l.writer != nil {
				fmt.Fprintln(l.writer, msgf())
			}
		}
	}
}
