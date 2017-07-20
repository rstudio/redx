docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

lua: docker-up
	docker-compose exec redx /usr/local/openresty/luajit/bin/moonc -t lua/ .

test: docker-up
	cp nginx.conf.example nginx.conf
	docker-compose exec redx /usr/local/openresty/luajit/bin/busted --output TAP --coverage --verbose spec
