ARGS=-v ${PWD}:/docker --workdir=/docker -e  AZURE_CLIENT_ID -e  AZURE_CLIENT_SECRET -e  AZURE_SUBSCRIPTION_ID -e  AZURE_TENANT_ID -e  KEY_VAULT_URI
run:
	docker run -d --rm --name py ${ARGS} py ./application.py

image:
	docker build -t py .

test:  
	docker exec -i -t py curl http://127.0.0.1:5000

debug:
	docker run -i -t --rm --name py ${ARGS} py bash 
