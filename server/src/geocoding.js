const { normalizeString } = require("./utils/values");

const userAgent = process.env.MTAXI_GEOCODING_USER_AGENT || "MTaxiBackend/0.1";

function parseNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function formatNominatimAddress(address = {}) {
  const road = normalizeString(
    address.road || address.pedestrian || address.footway || address.path || address.residential,
  );
  const house = normalizeString(address.house_number);
  const settlement = normalizeString(
    address.town ||
      address.village ||
      address.city ||
      address.hamlet ||
      address.municipality ||
      address.suburb ||
      address.neighbourhood,
  );
  const streetAndHouse = [road, house].filter(Boolean).join(" ");
  return [streetAndHouse, settlement].filter(Boolean).join(", ");
}

async function fetchJson(url) {
  if (typeof fetch !== "function") {
    return null;
  }
  const response = await fetch(url, {
    headers: {
      "User-Agent": userAgent,
      Accept: "application/json",
    },
  });
  if (!response.ok) {
    return null;
  }
  return response.json();
}

async function forwardGeocodeLookup(data = {}) {
  const query = normalizeString(data.query || data.address || data.q);
  if (!query) {
    return { success: false, code: "QUERY_REQUIRED", error: "Введите адрес" };
  }
  const params = new URLSearchParams({
    q: query,
    format: "jsonv2",
    limit: "1",
    addressdetails: "1",
  });
  const result = await fetchJson(`https://nominatim.openstreetmap.org/search?${params}`);
  const first = Array.isArray(result) ? result[0] : null;
  const lat = parseNumber(first?.lat);
  const lng = parseNumber(first?.lon);
  if (lat == null || lng == null) {
    return { success: false, code: "ADDRESS_NOT_FOUND", error: "Адрес не найден" };
  }
  return {
    success: true,
    code: "ADDRESS_FOUND",
    lat,
    lng,
    address: normalizeString(first.display_name),
  };
}

async function reverseGeocodeLookup(data = {}) {
  const lat = parseNumber(data.lat || data.latitude);
  const lng = parseNumber(data.lng || data.lon || data.longitude);
  if (lat == null || lng == null) {
    return { success: false, code: "COORDS_REQUIRED", error: "Передайте координаты" };
  }
  const params = new URLSearchParams({
    lat: String(lat),
    lon: String(lng),
    format: "jsonv2",
    addressdetails: "1",
    "accept-language": "ru",
  });
  const result = await fetchJson(`https://nominatim.openstreetmap.org/reverse?${params}`);
  const address = formatNominatimAddress(result?.address) || normalizeString(result?.display_name);
  if (!address) {
    return { success: false, code: "ADDRESS_NOT_FOUND", error: "Адрес не найден" };
  }
  return {
    success: true,
    code: "ADDRESS_FOUND",
    address,
    lat,
    lng,
  };
}

function countryComponents(country) {
  const value = normalizeString(country).toLowerCase();
  if (value === "ru") return "country:ru";
  if (value === "kz") return "country:kz";
  return "country:ru|country:kz";
}

function googlePlacesKey() {
  return normalizeString(process.env.MTAXI_GOOGLE_PLACES_API_KEY || process.env.GOOGLE_MAPS_API_KEY);
}

async function placesAutocomplete(data = {}) {
  const input = normalizeString(data.input || data.query || data.q);
  if (input.length < 2) {
    return { success: true, code: "PLACES_EMPTY", predictions: [], results: [] };
  }
  const language = normalizeString(data.language) || "ru";
  const types = normalizeString(data.types) || "address";
  const key = googlePlacesKey();
  if (key) {
    const params = new URLSearchParams({
      input,
      key,
      language,
      types,
      components: countryComponents(data.country || "both"),
    });
    if (normalizeString(data.locationbias)) {
      params.set("locationbias", normalizeString(data.locationbias));
    }
    const result = await fetchJson(`https://maps.googleapis.com/maps/api/place/autocomplete/json?${params}`);
    const predictions = Array.isArray(result?.predictions) ? result.predictions : [];
    return {
      success: result?.status === "OK" || result?.status === "ZERO_RESULTS",
      code: "PLACES_AUTOCOMPLETE",
      status: result?.status || "UNKNOWN",
      predictions,
      results: predictions,
    };
  }

  const params = new URLSearchParams({
    q: input,
    format: "jsonv2",
    limit: String(Number(data.limit) || 8),
    addressdetails: "1",
    "accept-language": language,
  });
  const result = await fetchJson(`https://nominatim.openstreetmap.org/search?${params}`);
  const predictions = (Array.isArray(result) ? result : []).map((item) => ({
    description: formatNominatimAddress(item.address) || normalizeString(item.display_name),
    formatted_address: formatNominatimAddress(item.address) || normalizeString(item.display_name),
    place_id: normalizeString(item.place_id) || normalizeString(item.osm_id),
    lat: parseNumber(item.lat),
    lng: parseNumber(item.lon),
    address: item.address || null,
  }));
  return {
    success: true,
    code: "PLACES_AUTOCOMPLETE",
    status: predictions.length ? "OK" : "ZERO_RESULTS",
    predictions,
    results: predictions,
  };
}

async function suggestAddressesLookup(data = {}) {
  const query = normalizeString(data.query || data.input || data.q);
  const city = normalizeString(data.city || data.region || data.cityRegionCountry);
  const limit = Math.min(Math.max(Number(data.limit) || 8, 1), 20);
  if (query.length < 2) {
    return { success: true, code: "ADDRESS_SUGGESTIONS_EMPTY", items: [], results: [] };
  }
  const input = city && !query.toLowerCase().includes(city.toLowerCase())
    ? `${query}, ${city}`
    : query;
  const autocomplete = await placesAutocomplete({
    ...data,
    input,
    query: input,
    limit,
  });
  const seen = new Set();
  const items = (autocomplete.predictions || [])
    .map((item) => normalizeString(item.description || item.formatted_address || item.name))
    .filter((item) => {
      if (!item || seen.has(item)) return false;
      seen.add(item);
      return true;
    })
    .slice(0, limit);
  return {
    success: autocomplete.success === true,
    code: "ADDRESS_SUGGESTIONS",
    status: autocomplete.status || "UNKNOWN",
    items,
    results: autocomplete.predictions || autocomplete.results || [],
  };
}

async function placeDetails(data = {}) {
  const placeId = normalizeString(data.placeId || data.place_id);
  const address = normalizeString(data.address || data.description);
  const lat = parseNumber(data.lat);
  const lng = parseNumber(data.lng || data.lon);
  if (lat != null && lng != null) {
    return {
      success: true,
      code: "PLACE_DETAILS",
      status: "OK",
      result: {
        name: address,
        formatted_address: address,
        place_id: placeId,
        geometry: { location: { lat, lng } },
        address_components: [],
      },
    };
  }

  const key = googlePlacesKey();
  if (key && placeId) {
    const params = new URLSearchParams({
      place_id: placeId,
      fields: "name,formatted_address,geometry,address_components,place_id",
      key,
      language: normalizeString(data.language) || "ru",
    });
    const result = await fetchJson(`https://maps.googleapis.com/maps/api/place/details/json?${params}`);
    return {
      success: result?.status === "OK",
      code: "PLACE_DETAILS",
      status: result?.status || "UNKNOWN",
      result: result?.result || null,
    };
  }

  if (address) {
    const forward = await forwardGeocodeLookup({ query: address });
    if (forward.success) {
      return {
        success: true,
        code: "PLACE_DETAILS",
        status: "OK",
        result: {
          name: address,
          formatted_address: forward.address || address,
          place_id: placeId,
          geometry: { location: { lat: forward.lat, lng: forward.lng } },
          address_components: [],
        },
      };
    }
  }
  return { success: false, code: "PLACE_NOT_FOUND", status: "NOT_FOUND", error: "Адрес не найден" };
}

async function routeLookup(data = {}) {
  const fromLat = parseNumber(data.fromLat ?? data.from?.lat ?? data.from?.latitude);
  const fromLng = parseNumber(data.fromLng ?? data.from?.lng ?? data.from?.lon ?? data.from?.longitude);
  const toLat = parseNumber(data.toLat ?? data.to?.lat ?? data.to?.latitude);
  const toLng = parseNumber(data.toLng ?? data.to?.lng ?? data.to?.lon ?? data.to?.longitude);
  if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
    return { success: false, code: "COORDS_REQUIRED", error: "Передайте точки маршрута" };
  }

  const profile = normalizeString(data.profile) || "driving";
  const result = await fetchJson(
    `https://router.project-osrm.org/route/v1/${profile}/${fromLng},${fromLat};${toLng},${toLat}?overview=full&geometries=geojson`,
  );
  const route = Array.isArray(result?.routes) ? result.routes[0] : null;
  const coordinates = Array.isArray(route?.geometry?.coordinates)
    ? route.geometry.coordinates
    : [];
  if (!route || coordinates.length === 0) {
    return { success: false, code: "ROUTE_NOT_FOUND", error: "Маршрут не найден" };
  }
  return {
    success: true,
    code: "ROUTE_FOUND",
    distanceMeters: parseNumber(route.distance) || 0,
    distanceKm: (parseNumber(route.distance) || 0) / 1000,
    durationSeconds: parseNumber(route.duration) || 0,
    durationMinutes: Math.round((parseNumber(route.duration) || 0) / 60),
    coordinates,
  };
}

module.exports = {
  forwardGeocodeLookup,
  reverseGeocodeLookup,
  placesAutocomplete,
  placeDetails,
  suggestAddressesLookup,
  routeLookup,
};
