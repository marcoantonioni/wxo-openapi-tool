# watsonx Orchestrate openApi tool

## Description

## Usage

```
wxo-openapi.sh
    -i input-openapi-file
        (eg: './services/test-openapi.json')
    -o output-openapi-file
        (eg: './output/adapted-openapi.json')
    -s (optional, all is default) select-security-type [basic|zen|all]
    -g (optional) generate properties structure for api operations [summary+description]
    -d (optional) properties-file for api summaries and descriptions 
    -k (optional) your-unique-id is used ad prefix for skills identification
```

## Examples

### Generate file for descriptions, summaries and phrases
parameters
```
-i input file (.json)
-g output file (.txt)
```
run
```
./wxo-openapi.sh \
  -i ./services/test-openapi-cp4ba-techzone.json \
  -g ./output/test-openapi-cp4ba-techzone.txt
```
#### Example of generated file
```
# service description
openapi.description=***set your api description here***

# startService
startService.summary=***set your service summary description here***
startService.description=***set your service operation description here***
startService.intents=***set your intents here, use comma separated phrases*** 
```

### Generate service for watsonx Orchestrate skills 
parameters
```
-i input file (.json)
-o output file (.json)
-s select basic authentication
-k use prefix 
-d load descriptions, summaries and phrases from file
```
run
```
./wxo-openapi.sh \
  -i ./services/test-openapi-cp4ba-techzone.json \
  -o ./output/wxo-openapi-adapted.json \
  -s basic \
  -k "MA-" \
  -d ./services/test-openapi-cp4ba-techzone.txt
```

