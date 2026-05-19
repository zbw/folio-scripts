## Agreement Lines als TSV

### PCI-Verknüpfung

#### Alle Agreement Lines mit PCI-Verknüpfung

```bash
jq -r '
  ["Resource ID", "Resource name", "Resource class", "Package name", "Package ID"] as $headers |
  $headers,
  ([.[] | select(.resource.class == "org.olf.kb.PackageContentItem")] |
    sort_by(.resource._object.pkg.name) |
    .[] |
    [.resource.id, .resource.name, .resource.class, .resource._object.pkg.name, .resource._object.pkg.id]
  ) | @tsv
' <JSON file>
```

#### Alle Agreement Lines mit PCI-Verknüpfung, gruppiert nach Agreement Line ID

```bash
jq -r '
  ["Agreement line IDs", "Resource ID", "Resource name", "Resource class", "Package name", "Package ID"] as $headers |
  $headers,
  ([.[] | select(.resource.class == "org.olf.kb.PackageContentItem")] |
    group_by(.resource.id) |
    sort_by(.[0].resource.name | split("in Package ") | if length > 1 then .[1] else "" end) |
    .[] |
    [(map(.id) | join("|")), .[0].resource.id, .[0].resource.name, .[0].resource.class,
     .[0].resource._object.pkg.name, .[0].resource._object.pkg.id]
  ) | @tsv
' <JSON file>
```

#### Alle Agreement Lines mit PCI-Verknüpfung, nur deren Paketname und Paket ID

```bash
jq -r '
  ["Package name", "Package ID"] as $headers |
  $headers,
  ([.[] | select(.resource.class == "org.olf.kb.PackageContentItem") |
    [.resource._object.pkg.name, .resource._object.pkg.id]] |
    unique |
    sort_by(.[0]) |
    .[] 
  ) | @tsv
' <JSON file>
```

### Paket-Verknüpfung

#### Alle Agreement Lines mit Paket-Verknüpfung, gruppiert nach Agreement Line ID

```bash
jq -r '
  ["Agreement line IDs", "Resource ID", "Resource name", "Resource class"] as $headers |
  $headers,
  ([.[] | select(.resource.class == "org.olf.kb.Pkg")] |
    group_by(.resource.id) |
    sort_by(.[0].resource.name) |
    .[] |
    [(map(.id) | join("|")), .[0].resource.id, .[0].resource.name, .[0].resource.class]
  ) | @tsv
' <JSON file>
```

#### Alle Agreement Lines mit Paket-Verknüpfung, nur deren Paketname und Paket ID

```bash
jq -r '
  ["Resource name", "Resource ID"] as $headers |
  $headers,
  ([.[] | select(.resource.class == "org.olf.kb.Pkg") |
    [.resource.name, .resource.id]] |
    unique |
    sort_by(.[0]) |
    .[]
  ) | @tsv
' <JSON file>
```
