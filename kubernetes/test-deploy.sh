#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace production \
	students \
	./students
