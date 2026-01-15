package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Tylerx404/z2api-go/middleware"
)

// UsageHandler returns usage statistics for proxy API keys
func UsageHandler(w http.ResponseWriter, r *http.Request) {
	auth := middleware.GetAuthMiddleware()

	// Only allow if auth is enabled (admin endpoint)
	if !auth.GetRequireAuth() {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error":"Proxy authentication is not enabled"}`))
		return
	}

	usage := auth.GetUsage()

	response := map[string]interface{}{
		"total_keys": len(usage),
		"keys":       usage,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
