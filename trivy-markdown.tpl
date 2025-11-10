{{- if . }}
# {{ escapeXML ( index . 0).Target }} - Trivy Report - {{ now }}
{{- range . }}
## {{ .Type | toString | escapeXML }} - `{{ escapeXML .Target }}`
{{- if (eq (len .Vulnerabilities) 0) }}
✅ No Vulnerabilities found
{{- else }}
### Vulnerabilities ({{ len .Vulnerabilities }})
| Package | ID | Severity | Installed Version | Fixed Version | Title |
| -------- | ---- | -------- | ---------------- | ------------ | ---- |
{{- range .Vulnerabilities }}
| `{{ escapeXML .PkgName }}{{- if .PkgPath -}}<br/>{{ escapeXML .PkgPath}}{{- end -}}` | [{{ escapeXML .VulnerabilityID }}]({{ escapeXML .PrimaryURL }}) | {{ escapeXML .Severity }} | {{ escapeXML .InstalledVersion }} | {{ escapeXML .FixedVersion }} | {{ escapeXML .Title }} |
{{- end }}

{{- end }}
{{- end }}
{{- else }}
✅ No Vulnerabilities found
{{- end }}