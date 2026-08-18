// The static Leaflet imports — library and stylesheet — reached ONLY through
// the dynamic import() in MapBinder, so a document with no map never loads
// either. Markers are drawn as circleMarkers (vectors): Leaflet's default icon
// is a PNG whose bundler-mangled path is the classic broken-marker bug, and a
// circle needs no asset at all.

%%raw(`
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
if (typeof globalThis !== "undefined") globalThis.__rnLeaflet = L;
`)

/** The Leaflet namespace, for the binder's raw code. */
let leaflet: {..} = %raw(`globalThis.__rnLeaflet`)
