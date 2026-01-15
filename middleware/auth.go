package middleware

import (
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/Tylerx404/z2api-go/config"
)

// UsageStats tracks usage per API key
type UsageStats struct {
	TotalRequests int64
	LastUsed      time.Time
}

// AuthMiddleware handles proxy API key authentication
type AuthMiddleware struct {
	keys         map[string]string // Key -> Name/Description
	usage        map[string]*UsageStats
	usageMutex   sync.RWMutex
	requireAuth  bool
}

var (
	authMiddleware *AuthMiddleware
	authOnce       sync.Once
)

// GetAuthMiddleware returns the singleton auth middleware instance
func GetAuthMiddleware() *AuthMiddleware {
	authOnce.Do(func() {
		cfg := config.GetConfig()
		authMiddleware = &AuthMiddleware{
			keys:        cfg.API.ProxyKeys,
			usage:       make(map[string]*UsageStats),
			requireAuth: len(cfg.API.ProxyKeys) > 0,
		}
	})
	return authMiddleware
}

// Authenticate validates the proxy API key and returns key name if valid
func (am *AuthMiddleware) Authenticate(key string) (string, bool) {
	if !am.requireAuth {
		return "anonymous", true
	}

	if name, ok := am.keys[key]; ok {
		return name, true
	}

	return "", false
}

// RecordUsage records a request for an API key
func (am *AuthMiddleware) RecordUsage(keyName string) {
	am.usageMutex.Lock()
	defer am.usageMutex.Unlock()

	if am.usage[keyName] == nil {
		am.usage[keyName] = &UsageStats{}
	}

	stats := am.usage[keyName]
	stats.TotalRequests++
	stats.LastUsed = time.Now()
}

// GetUsage returns usage stats for all keys
func (am *AuthMiddleware) GetUsage() map[string]*UsageStats {
	am.usageMutex.RLock()
	defer am.usageMutex.RUnlock()

	// Return a copy to avoid concurrent access issues
	result := make(map[string]*UsageStats, len(am.usage))
	for k, v := range am.usage {
		result[k] = &UsageStats{
			TotalRequests: v.TotalRequests,
			LastUsed:      v.LastUsed,
		}
	}
	return result
}

// AuthHandler creates a middleware that validates proxy API keys
func (am *AuthMiddleware) AuthHandler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip auth for health endpoint
		if r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}

		// Extract API key from Authorization header
		authHeader := r.Header.Get("Authorization")
		var apiKey string

		if authHeader != "" {
			// Support "Bearer <key>" format
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
				apiKey = strings.TrimSpace(parts[1])
			} else {
				// Also support raw key in header
				apiKey = strings.TrimSpace(authHeader)
			}
		}

		// Authenticate
		keyName, valid := am.Authenticate(apiKey)
		if !valid {
			log.Printf("[AUTH] Failed attempt from %s - missing or invalid API key", r.RemoteAddr)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error":{"message":"Invalid or missing proxy API key","type":"authentication_error"}}`))
			return
		}

		// Record usage
		am.RecordUsage(keyName)

		if am.requireAuth {
			log.Printf("[AUTH] %s - %s %s - key: %s", r.RemoteAddr, r.Method, r.URL.Path, keyName)
		}

		// Call next handler
		next.ServeHTTP(w, r)
	})
}

// GetRequireAuth returns whether authentication is required
func (am *AuthMiddleware) GetRequireAuth() bool {
	return am.requireAuth
}
