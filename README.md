# Elasticsearch Clean up & Retention
Delete indices provided or query a date range of logs then delete them. This can be implemented as a retention policy for Logstash with a cron job or ran only when needed.
```
This script is used for cleaning up Elasticsearch indices.
Please update your Elasticsearch credentials in this script

Usage: ./cleanup.sh {o} {url} {index} {days}

Example:
  ./cleanup.sh -d http://localhost:9200 .management-beats
  ./cleanup.sh -r http://localhost:9200 chat 15

Options:
  -d | --delete     Delete an entire index
  -r | --retain     Query an index back in time, logs saved locally

```
