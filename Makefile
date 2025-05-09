
swift_files := Package.swift Sources Tests Examples/SmokeTest Examples/CocoaPodsTest/CocoaPodsTest*

lint:
	swift format lint --strict --recursive $(swift_files)

format:
	swift format format --in-place --recursive $(swift_files)

cocoapods-tests:
	# pod lib lint honeycomb-opentelemetry-swift.podspec
	cd Examples/CocoaPodsTest && sh ./run-cocoapods-test.sh

#: cleans up smoke test output
clean-smoke-tests:
	rm -rf ./smoke-tests/collector/data.json
	rm -rf ./smoke-tests/collector/data-results/*.json
	rm -rf ./smoke-tests/report.*

smoke-tests/collector/data.json:
	@echo ""
	@echo "+++ Zhuzhing smoke test's Collector data.json"
	@touch $@ && chmod o+w $@

smoke-docker: smoke-tests/collector/data.json
	@echo ""
	@echo "+++ Spinning up the smokers."
	@echo ""
	docker compose up --build collector --build mock-server --detach

ios-tests: smoke-tests/collector/data.json
	@echo ""
	@echo "+++ Running iOS tests."
	@echo ""
	bash ./run-ios-tests.sh

smoke-bats: smoke-tests/collector/data.json
	@echo ""
	@echo "+++ Running bats smoke tests."
	@echo ""
	cd smoke-tests && bats ./smoke-e2e.bats --report-formatter junit --output ./

smoke: smoke-docker ios-tests smoke-bats

unsmoke:
	@echo ""
	@echo "+++ Spinning down the smokers."
	@echo ""
	docker compose down --volumes
