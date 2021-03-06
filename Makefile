clean:
	rm -rf ./dist

build-erdpy: clean
	python3 setup.py sdist

publish-erdpy: build
	twine upload dist/*

test-short:
	python3 -m unittest -v erdpy.tests.test_wallet
	python3 -m unittest -v erdpy.tests.test_accounts
	python3 -m unittest -v erdpy.tests.test_contracts

test-all:
	python3 -m unittest discover -s erdpy/tests

arwendebug:
	# When referencing a non-released version, add the commit hash, like this: arwen-wasm-vm/cmd/arwendebug@...
	# When referencing a released version, use the actual version instead: arwen-wasm-vm/cmd/arwendebug v0.3.14
	GO111MODULE=on GOPATH=$(shell pwd)/distribution/go go get github.com/ElrondNetwork/arwen-wasm-vm/cmd/arwendebug@a0e1bf5da9f57ffbc3596bc9631b0f18e7c34832
	stat ./distribution/go/bin/arwendebug

test-cli: test-cli-accounts, test-cli-network
	python3 -m erdpy.cli templates --json

	python3 -m erdpy.cli wallet generate ./myaccount.pem
	python3 -m erdpy.cli wallet bech32 --encode 000000000000000005006e4f90488e27342f9a46e1809452c85ee7186566bd5e
	python3 -m erdpy.cli wallet bech32 --decode erd1qqqqqqqqqqqqqpgqde8eqjywyu6zlxjxuxqfg5kgtmn3setxh40qen8egy

	python3 -m erdpy.cli cost gas-price --proxy=https://api.elrond.com
	python3 -m erdpy.cli cost transaction move-balance --data="foobar" --proxy="https://api.elrond.com"

test-cli-accounts:
	python3 -m erdpy.cli account get --address="erd188nydpkagtpwvfklkl2tn0w6g40zdxkwfgwpjqc2a2m2n7ne9g8q2t22sr" --proxy="https://api.elrond.com"
	python3 -m erdpy.cli account get --nonce --address="erd188nydpkagtpwvfklkl2tn0w6g40zdxkwfgwpjqc2a2m2n7ne9g8q2t22sr" --proxy="https://api.elrond.com"
	python3 -m erdpy.cli account get --balance --address="erd188nydpkagtpwvfklkl2tn0w6g40zdxkwfgwpjqc2a2m2n7ne9g8q2t22sr" --proxy="https://api.elrond.com"
	python3 -m erdpy.cli account get-transactions --address="erd188nydpkagtpwvfklkl2tn0w6g40zdxkwfgwpjqc2a2m2n7ne9g8q2t22sr" --proxy="https://api.elrond.com"

test-cli-network:
	#python3 -m erdpy.cli network num-shards --proxy="https://api.elrond.com"
	#python3 -m erdpy.cli network chain-id --proxy="https://api.elrond.com"
	#python3 -m erdpy.cli network last-block-nonce --shard-id="1" --proxy="https://api.elrond.com"
	python3 -m erdpy.cli network meta-nonce --proxy="https://api.elrond.com"
	python3 -m erdpy.cli network meta-block --proxy="https://api.elrond.com" --nonce=1
	#python3 -m erdpy.cli network meta-nonce --proxy="http://localhost:8001"
	#python3 -m erdpy.cli network meta-block --proxy="http://localhost:8001" --nonce=1

test-cli-blockatlas:
	python3 -m erdpy.cli blockatlas --url="http://localhost:8420" --coin="elrond" current-block-number
	python3 -m erdpy.cli blockatlas --url="http://localhost:8420" --coin="elrond" block-by-number --number=42
	python3 -m erdpy.cli blockatlas --url="http://localhost:8420" --coin="elrond" transactions --address="alice" 

test-cli-validators:
	python3 -m erdpy.cli --verbose stake --pem="./examples/keys/alice.pem" --number-of-nodes=1 --nodes-public-keys="blsKey1" --value="2500000000000000000000000" --proxy=https://api.elrond.com --reward-address="erd1l453hd0gt5gzdp7czpuall8ggt2dcv5zwmfdf3sd3lguxseux2fsmsgldz"
	python3 -m erdpy.cli --verbose unstake --pem="./examples/keys/alice.pem" --nodes-public-keys="blsKey1" --proxy=https://api.elrond.com
	python3 -m erdpy.cli --verbose unbond --pem="./examples/keys/alice.pem" --nodes-public-keys="blsKey1" --proxy=https://api.elrond.com
	python3 -m erdpy.cli --verbose unjail --pem="./examples/keys/alice.pem" --value=500000000000000000000 --nodes-public-keys="blsKey1" --proxy=https://api.elrond.com
	python3 -m erdpy.cli --verbose change-reward-address --pem="./examples/keys/alice.pem" --reward-address="erd1l453hd0gt5gzdp7czpuall8ggt2dcv5zwmfdf3sd3lguxseux2fsmsgldz" --proxy=https://api.elrond.com

test-cli-dispatcher:
	python3 -m erdpy.cli dispatcher enqueue --value="100" --receiver="erd1cux02zersde0l7hhklzhywcxk4u9n4py5tdxyx7vrvhnza2r4gmq4vw35r" --data="foo" --gas-price=200000000000 --gas-limit=50000000
	python3 -m erdpy.cli dispatcher enqueue --value="200" --receiver="erd1cux02zersde0l7hhklzhywcxk4u9n4py5tdxyx7vrvhnza2r4gmq4vw35r" --data="foo" --gas-price=200000000000 --gas-limit=50000000
	python3 -m erdpy.cli dispatcher enqueue --value="300" --receiver="erd1cux02zersde0l7hhklzhywcxk4u9n4py5tdxyx7vrvhnza2r4gmq4vw35r" --data="foo" --gas-price=200000000000 --gas-limit=50000000
	python3 -m erdpy.cli --verbose dispatcher dispatch --proxy="https://api.elrond.com" --pem="./examples/keys/alice.pem"
	#python3 -m erdpy.cli --verbose dispatcher dispatch-continuously --interval=1 --proxy="https://api.elrond.com" --pem="./examples/keys/alice.pem"

test-cli-external-contracts:
ifndef SANDBOX
	$(error SANDBOX variable is undefined)
endif
	rm -rf ${SANDBOX}/myanswer
	rm -rf ${SANDBOX}/myadder
	rm -rf ${SANDBOX}/sc-busd-rs

	# Ultimate answer (C)
	python3 -m erdpy.cli new --template ultimate-answer --directory ${SANDBOX} myanswer
	python3 -m erdpy.cli build ${SANDBOX}/myanswer

	# Adder (rust)
	python3 -m erdpy.cli new --template adder --directory ${SANDBOX} myadder
	python3 -m erdpy.cli build ${SANDBOX}/myadder
	python3 -m erdpy.cli test --directory="test" ${SANDBOX}/myadder

	# BUSD (rust)
	git clone --depth=1 --branch=master https://github.com/ElrondNetwork/sc-busd-rs.git ${SANDBOX}/sc-busd-rs
	rm -rf ${SANDBOX}/sc-busd-rs/.git
	python3 -m erdpy.cli build ${SANDBOX}/sc-busd-rs
	python3 -m erdpy.cli test --directory="tests" ${SANDBOX}/sc-busd-rs

test-deployment:
	python3 -m examples.mycounter_testnet --proxy=https://api.elrond.com --pem=./examples/keys/alice.pem

list-s3:
	aws s3 ls s3://ide.elrond.com --recursive --human-readable --summarize
