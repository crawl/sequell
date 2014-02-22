all: test

test: unit integration

unit:
	rspec spec
	prove t

integration:
	perl ./scripts/test-henzell.pl --fail-fast
