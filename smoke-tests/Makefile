#: cleans up smoke test output
clean-smoke-tests:
	rm -rf ./collector/data.json
	rm -rf ./collector/data-results/*.json
	rm -rf ./report.*

collector/data.json:
	@echo ""
	@echo "+++ Zhuzhing smoke test's Collector data.json"
	@touch $@ && chmod o+w $@

smoke-docker: collector/data.json
	@echo ""
	@echo "+++ Spinning up the smokers."
	@echo ""
	docker-compose up --build collector --detach

ios-tests: collector/data.json
	@echo ""
	@echo "+++ Running iOS tests."
	@echo ""
	cd .. && bash ./run-ios-tests.sh

smoke-bats: collector/data.json
	@echo ""
	@echo "+++ Running bats smoke tests."
	@echo ""
	bats ./smoke-e2e.bats --report-formatter junit --output ./

smoke: smoke-docker ios-tests smoke-bats

unsmoke:
	@echo ""
	@echo "+++ Spinning down the smokers."
	@echo ""
	docker-compose down --volumes
