# SwiftTileserverCache

## Changelog

Summary of changes from base repository:

### Features
- **Prometheus metrics** - Full observability via `/metrics` endpoint
- **ARM64 support** - Native builds for arm64/aarch64 architecture
- **GitHub Actions CI** - Automated Docker image builds on push to master
- **Grafana dashboard** - Pre-built dashboard for metrics visualization
- **Improved logging** - Less spam, more useful data
- **Swift 6.0** - Upgraded to latest Swift version

### Fixes
- **Memory optimizations** - Reduced memory usage and fixed leaks
- **FileToucher stability** - Fixed crashes and improved queue handling
- **Cache cleaner** - Fixed broken cache image cleanup
- **Dockerfile** - Updated for Swift 6.0 and arm64 compatibility

## Installing

Pre-built Docker images are available at `ghcr.io/lenisko/swifttileservercache:latest` for both amd64 and arm64 architectures.

- Install Docker
- Create a new folder to store the yml file in and change into it: `mkdir TileServer && cd TileServer`
- Load the yml: `wget https://raw.githubusercontent.com/lenisko/SwiftTileserverCache/master/docker-compose.yml`
- Edit the docker-compose.yml file if you want to change defaults. Default will work fine.
- Create a new folder to store TileServer data in and chagne into it: `mkdir TileServer && cd TileServer`
- Get Download command from https://openmaptiles.com/downloads/planet/ for your region.
- Download the file using wget.
- Rename file to end in .mbtiles if it got named incorrectly
- Change one layer back into the folder where the docker-compose.yml file is located: `cd ..`
- Start and attach to logs: `docker-compose up -d && docker-compose logs -f`

## Formats

- Tiles: 
    - `GET tile/{style}/{z}/{x}/{y}/{scale}/{format}`
- StaticMap: 
    - `POST /staticmap` (StaticMap Object in JSON Format as POST body)
    - `GET /staticmap` (SaticMap Object in URL Parameters using URL-encoding)
    - `GET /staticmap/:template` (Template Enviroment parsed from URL Parameters)
    - `POST /staticmap/:template` (Template Enviroment in JSON Format Format as POST body)
    - `GET /staticmap/pregenerated/:id` (Get image from pregenerated map. Use GET or POST to /staticmap with pregenerate=true as URL Parameter to get pregenerate the map)
- MutliStaticMap:
    - `POST /multistaticmap` (MultiStaticMap Object in JSON Format as POST body)
    - `POST /multistaticmap` (MultiStaticMap Object in URL Parameters using URL-encoding)
    - `GET /multistaticmap/:template` (Template Enviroment parsed from URL Parameters. Parameters ending in `json` will be parsed as json. Multiple instances of same Parameter will be parsed as array)
    - `POST /multistaticmap/:template` (Template Enviroment in JSON Format Format as POST body)
    - `GET /multistaticmap/pregenerated/:id` (Get image from pregenerated map. Use GET or POST to /staticmap with pregenerate=true as URL Parameter to get pregenerate the map)
- Metrics:
    - `GET /metrics` (Prometheus metrics endpoint)

### Style
Get a list of styles by visiting `/styles`
Checkout https://tileserver.readthedocs.io for a guide on how to add more styles.

### StaticMap
StaticMap route accepts an StaticMap Object JSON Object as POST body:
Example:
```
{
  "style": string (check avilable styles at /styles),
  "latitude": double,
  "longitude": double,
  "zoom": int,
  "width": int,
  "height": int,
  "scale": int,
  "format": string? (png, jpg, ...),
  "bearing": double?,
  "pitch": double?,
  "markers": [Marker]?,
  "polygons": [Geofence]?,
  "circles": [Circle]?"
}
```

### MultiStaticMap
MultiStaticMap route accepts an MultiStaticMap JSON Object as POST Body:
Example:
```
{
  "grid": [
    {
      "direction": string (always "first"),
      "maps": [
        {
          "direction": string (always "first"),
          "map": StaticMap
        }, {
          "direction": string ("right", or "bottom"),
          "map": StaticMap
        }, 
        ...
      ]
    }, {
      "direction": string ("right", or "bottom"),
      "maps": [
        {
          "direction": string (always "first"),
          "map": StaticMap
        }, {
          "direction": string ("right", or "bottom"),
          "map": StaticMap
        }, 
        ...
      ]
    },
    ...
  ]
}
```

### Marker
Marker JSON used in StaticMap:
Example:
```
{
  "url": string,
  "height": int,
  "width": int,
  "x_offset": int,
  "y_offset": int,
  "latitude": double,
  "longitude": double
}
```

### Polygon
Polygon JSON used in StaticMap:
Example:
```
{
  "fill_color": string (imagemagick color string),
  "stroke_color": string (imagemagick color string),
  "stroke_width": int,
  "path": [
    [double (lat), double (lon)],
    [double, double],
    ...
  ]
}
```

### Circle
Circle JSON used in StaticMap:
Example:
```
{
  "fill_color": string (imagemagick color string),
  "stroke_color": string (imagemagick color string),
  "stroke_width": int,
  "radius": double,
  "latitude": double,
  "longitude": double
}
```

## Examples

### Tiles
`GET https://tileserverurl/tile/klokantech-basic/{z}/{x}/{y}/2/png`

### StaticMap
`GET https://tileserverurl/staticmap?style=klokantech-basic&latitude=47.263416&longitude=11.400512&zoom=17&width=500&height=500&scale=2`

### Pregenerate StaticMap
Pregenerate: `GET https://tileserverurl/staticmap?style=klokantech-basic&latitude=47.263416&longitude=11.400512&zoom=17&width=500&height=500&scale=2&pregenerate=true`
Returns: `id`
View: `GET https://tileserverurl/staticmap/pregenerated/{id}`


### StaticMap with Markers
`POST https://tileserverurl/staticmap`
```JSON
{
    "style": "klokantech-basic",
    "latitude": 47.263416,
    "longitude": 11.400512,
    "zoom": 17,
    "width": 500,
    "height": 500,
    "scale": 1,
    "markers": [
        {
            "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Map_marker.svg/1200px-Map_marker.svg.png",
            "latitude": 47.263416,
            "longitude": 11.400512,
            "width": 50,
            "height": 50
        }
    ]
}
```
![staticmap response](.exampleimages/staticmap.png)

### MultiStaticMap
`POST https://tileserverurl/multistaticmap`
```JSON
{
    "grid": [
        {
            "direction": "first",
            "maps": [
                {
                    "direction": "first",
                    "map": {
                        "style": "klokantech-basic",
                        "latitude": 47.263416,
                        "longitude": 11.400512,
                        "zoom": 17,
                        "width": 500,
                        "height": 250,
                        "scale": 1,
                        "markers": [
                            {
                                "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Map_marker.svg/1200px-Map_marker.svg.png",
                                "latitude": 47.263416,
                                "longitude": 11.400512,
                                "width": 50,
                                "height": 50
                            }
                        ]
                    }
                }
            ]
        },
        {
            "direction": "bottom",
            "maps": [
                {
                    "direction": "first",
                    "map": {
                        "style": "klokantech-basic",
                        "latitude": 47.263416,
                        "longitude": 11.400512,
                        "zoom": 15,
                        "width": 300,
                        "height": 100,
                        "scale": 1,
                        "markers": [
                            {
                                "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Map_marker.svg/1200px-Map_marker.svg.png",
                                "latitude": 47.263416,
                                "longitude": 11.400512,
                                "width": 25,
                                "height": 25
                            }
                        ]
                    }
                },
                {
                    "direction": "right",
                    "map": {
                        "style": "klokantech-basic",
                        "latitude": 47.263416,
                        "longitude": 11.400512,
                        "zoom": 12,
                        "width": 200,
                        "height": 100,
                        "scale": 1,
                        "markers": [
                            {
                                "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Map_marker.svg/1200px-Map_marker.svg.png",
                                "latitude": 47.263416,
                                "longitude": 11.400512,
                                "width": 25,
                                "height": 25
                            }
                        ]
                    }
                }
            ]
        }
    ]
}
```
![multistaticmap response](.exampleimages/multistaticmap.png)

### StaticMap using Templates
`pokemon.json` file in `Templates` directory (uses [Leaf](https://docs.vapor.codes/4.0/leaf/overview/) as TemplatingEngine):
```
{
    "style": "klokantech-basic",
    "latitude": #(lat),
    "longitude": #(lon),
    "zoom": 15,
    "width": 500,
    "height": 250,
    "scale": 1,
    "markers": [
        {
        "url": "https://rdmurl/static/img/pokemon/#(id)#if(form != nil):-#(form)#endif.png",
            "latitude": #(lat),
            "longitude": #(lon),
            "width": 50,
            "height": 50
        }
    ]
}
```
`GET https://tileserverurl/staticmap/pokemon?id=201&lat=47.263416&lon=11.400512&form=5`
![staticmap-template response](.exampleimages/staticmaptemplate.png)


## Metrics

The `/metrics` endpoint exposes Prometheus-compatible metrics for monitoring:

| Metric | Type | Description |
|--------|------|-------------|
| `tileserver_uptime_seconds` | Gauge | Process uptime in seconds |
| `tileserver_memory_resident_bytes` | Gauge | Resident memory usage |
| `tileserver_memory_virtual_bytes` | Gauge | Virtual memory usage |
| `tileserver_requests_total` | Counter | Total requests by type, style, and cache status |
| `tileserver_requests_in_flight` | Gauge | Currently processing requests by type |
| `tileserver_request_duration_seconds` | Histogram | Request duration distribution |
| `tileserver_cache_hits_total` | Counter | Cache hits by request type |
| `tileserver_cache_misses_total` | Counter | Cache misses by request type |
| `tileserver_errors_total` | Counter | Errors by type and reason |
| `tileserver_http_client_requests_total` | Counter | Outgoing HTTP requests by host |
| `tileserver_http_client_duration_seconds` | Histogram | Outgoing HTTP request duration |
| `tileserver_filetoucher_queue_size` | Gauge | File toucher queue size |

A Grafana dashboard is included in the main directory.

### Notes

Thanks to @123FLO321 for years of SwiftTileserverCache development. And @3nprob for node-fontnik with arm64 support.