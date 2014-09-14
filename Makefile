all: seqdb

seqdb:
	go get -u github.com/greensnark/go-sequell/cli/seqdb

test: unit integration

unit:
	rspec spec
	prove t

integration:
	perl ./scripts/test-henzell.pl --fail-fast
