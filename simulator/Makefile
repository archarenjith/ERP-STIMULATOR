.PHONY: run build test

run:
	uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

build:
	docker build -t manufacturing-erp-simulator:latest .

test:
	python -m unittest discover -s tests -v
