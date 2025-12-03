// config/config.go
package config

import (
	"encoding/xml"
	"fmt"
	"os"
	"time"
)

type Config struct {
	XMLName      xml.Name `xml:"Config"`
	GrpcPort     string   `xml:"GrpcPort"`
	GeminiModel  string   `xml:"GeminiModel"`
	BatchSize    int      `xml:"BatchSize"`
	BatchTimeout int      `xml:"BatchTimeout"`
	GoogleAPIKey string   `xml:"GoogleApiKey"`

	// Data source control
	UseInternalDB      bool   `xml:"UseInternalDB"`
	ExternalProductURL string `xml:"ExternalProductURL"`

	// CSV seed file
	SeedFile string `xml:"SeedFile"`

	// === NEW: Image Web Server ===
	WebServerPort string `xml:"WebServerPort"`
	ImageDir      string `xml:"ImageDir"`

	// Store information for receipts
	StoreName    string `xml:"StoreName"`
	StoreAddress string `xml:"StoreAddress"`
	StoreCity    string `xml:"StoreCity"`
	StoreCountry string `xml:"StoreCountry"`

	OrderConfirmationCallback string `xml:"OrderConfirmationCallback"`
}

var (
	GrpcPort           string
	GeminiModel        string
	BatchSize          int
	BatchTimeout       time.Duration
	GoogleAPIKey       string
	UseInternalDB      bool
	ExternalProductURL string
	SeedFile           string

	WebServerPort string
	ImageDir      string

	StoreName    string
	StoreAddress string
	StoreCity    string
	StoreCountry string

	OrderConfirmationCallback string
)

func LoadConfig(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read config %s: %w", path, err)
	}

	var cfg Config
	if err := xml.Unmarshal(data, &cfg); err != nil {
		return fmt.Errorf("failed to parse XML: %w", err)
	}

	// Assign to package-level vars
	GrpcPort = cfg.GrpcPort
	GeminiModel = cfg.GeminiModel
	BatchSize = cfg.BatchSize
	BatchTimeout = time.Duration(cfg.BatchTimeout) * time.Millisecond
	GoogleAPIKey = cfg.GoogleAPIKey
	UseInternalDB = cfg.UseInternalDB
	ExternalProductURL = cfg.ExternalProductURL
	SeedFile = cfg.SeedFile

	// Image server settings
	WebServerPort = cfg.WebServerPort
	ImageDir = cfg.ImageDir

	// Store information
	StoreName = cfg.StoreName
	StoreAddress = cfg.StoreAddress
	StoreCity = cfg.StoreCity
	StoreCountry = cfg.StoreCountry

	OrderConfirmationCallback = cfg.OrderConfirmationCallback

	return nil
}

// === Getters ===
func GetAPIKey() string              { return GoogleAPIKey }
func GetModelName() string           { return GeminiModel }
func GetPort() string                { return GrpcPort }
func GetBatchSize() int              { return BatchSize }
func GetBatchTimeout() time.Duration { return BatchTimeout }

func GetInternalDB() bool       { return UseInternalDB }
func GetExternalSource() string { return ExternalProductURL }
func GetSeedFile() string       { return SeedFile }

// === NEW: Image Server Getters ===
func GetWebServerPort() string { return WebServerPort }
func GetImageDir() string      { return ImageDir }

// === NEW: Store Information Getters ===
func GetStoreName() string    { return StoreName }
func GetStoreAddress() string { return StoreAddress }
func GetStoreCity() string    { return StoreCity }
func GetStoreCountry() string { return StoreCountry }

func GetOrderConfirmationCallback() string {
	return OrderConfirmationCallback
}
