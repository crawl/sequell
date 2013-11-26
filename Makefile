all: test

test: unit integration

unit:
	rspec spec
	prove t

integration:
	perl test-henzell.pl --fail-fast
