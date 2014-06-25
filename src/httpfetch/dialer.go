package httpfetch

import (
	"net"
	"time"
)

type timedOutConnection struct {
	timeout time.Duration
	net.Conn
}

func (t *timedOutConnection) Read(b []byte) (n int, err error) {
	if t.timeout > 0 {
		deadline := time.Now().Add(t.timeout)
		t.Conn.SetReadDeadline(deadline)
	}
	return t.Conn.Read(b)
}

func dialer(connectTimeout, readTimeout time.Duration) func(string, string) (net.Conn, error) {
	return func(network, addr string) (conn net.Conn, err error) {
		conn, err = net.DialTimeout(network, addr, connectTimeout)
		if err != nil {
			return
		}
		return &timedOutConnection{readTimeout, conn}, nil
	}
}
