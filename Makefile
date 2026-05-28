all: seqdb

seqdb:
	go install github.com/crawl/go-sequell/cmd/seqdb@latest

test: unit integration

unit:
	bundle exec rspec spec
	prove t

integration:
	perl ./scripts/test-henzell.pl --fail-fast
