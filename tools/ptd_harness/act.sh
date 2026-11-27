#!/bin/bash
curl -s --max-time 280 -X POST localhost:9000/act -d "$1"
