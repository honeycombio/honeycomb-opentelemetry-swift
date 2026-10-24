#!/usr/bin/env python3
"""A local OTLP/HTTP sink for the passthrough experiment.

Accepts protobuf or JSON on /v1/traces, /v1/logs and /v1/metrics, and appends one normalized JSON
line per request to the file given as argv[2]. Binds to loopback only. Never forwards anything.

usage: sink.py PORT OUTFILE
"""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from google.protobuf.json_format import MessageToDict
from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import ExportTraceServiceRequest
from opentelemetry.proto.collector.logs.v1.logs_service_pb2 import ExportLogsServiceRequest
from opentelemetry.proto.collector.metrics.v1.metrics_service_pb2 import ExportMetricsServiceRequest

TYPES = {"/v1/traces": ExportTraceServiceRequest, "/v1/logs": ExportLogsServiceRequest,
         "/v1/metrics": ExportMetricsServiceRequest}


def value(v):
    (kind, x), = v.items()
    if kind == "intValue": return int(x)
    if kind == "arrayValue": return [value(i) for i in x.get("values", [])]
    if kind == "kvlistValue": return {kv["key"]: value(kv["value"]) for kv in x.get("values", [])}
    return x


def attrs(lst):
    return {kv["key"]: value(kv["value"]) for kv in lst or []}


def normalize(path, req):
    out = []
    for rk in ("resourceSpans", "resourceLogs", "resourceMetrics"):
        for r in req.get(rk, []):
            res = attrs(r.get("resource", {}).get("attributes"))
            for sk in ("scopeSpans", "scopeLogs", "scopeMetrics"):
                for s in r.get(sk, []):
                    scope = s.get("scope", {})
                    for k in ("spans", "logRecords", "metrics"):
                        for item in s.get(k, []):
                            rec = {"signal": k, "resource": res, "scope": scope.get("name", ""),
                                   "scopeVersion": scope.get("version", ""), "attributes": attrs(item.get("attributes"))}
                            if k == "spans":
                                rec.update(name=item["name"], kind=item.get("kind"), start=int(item["startTimeUnixNano"]),
                                           end=int(item["endTimeUnixNano"]), status=item.get("status", {}),
                                           parent=item.get("parentSpanId"), traceId=item["traceId"])
                            elif k == "logRecords":
                                rec.update(time=int(item.get("timeUnixNano", 0)), severity=item.get("severityText") or item.get("severityNumber"),
                                           eventName=item.get("eventName"), body=item.get("body"))
                            else:
                                rec.update(name=item["name"])
                            out.append(rec)
    return out


class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        path = self.path.split("?")[0]
        cls = TYPES.get(path)
        if cls is None:
            self.send_response(404); self.end_headers(); return
        ctype = self.headers.get("Content-Type", "")
        if "json" in ctype:
            req = json.loads(body)
        else:
            m = cls(); m.ParseFromString(body)
            req = MessageToDict(m)
        line = {"path": path, "contentType": ctype,
                "headers": {k.lower(): v for k, v in self.headers.items() if k.lower() not in ("host", "content-length", "accept-encoding", "connection")},
                "records": normalize(path, req)}
        with open(OUT, "a") as f:
            f.write(json.dumps(line) + "\n")
        self.send_response(200); self.send_header("Content-Type", "application/x-protobuf"); self.send_header("Content-Length", "0"); self.end_headers()

    def log_message(self, *a): pass


if __name__ == "__main__":
    OUT = sys.argv[2]
    HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
