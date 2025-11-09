package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const (
	SandboxURL    = "https://sandbox.itunes.apple.com/verifyReceipt"
	ProductionURL = "https://buy.itunes.apple.com/verifyReceipt"
)

type VerifyRequest struct {
	Receipt      string `json:"receipt"`
	SharedSecret string `json:"shared_secret,omitempty"`
	Sandbox      bool   `json:"sandbox,omitempty"`
}

type AppleVerifyPayload struct {
	ReceiptData            string `json:"receipt-data"`
	Password               string `json:"password,omitempty"`
	ExcludeOldTransactions bool   `json:"exclude-old-transactions"`
}

type AppleResponse struct {
	Status             int              `json:"status"`
	Receipt            map[string]any   `json:"receipt,omitempty"`
	LatestReceiptInfo  []map[string]any `json:"latest_receipt_info,omitempty"`
	PendingRenewalInfo []map[string]any `json:"pending_renewal_info,omitempty"`
	Error              string           `json:"error,omitempty"`
}

type VerifyResponse struct {
	Valid              bool             `json:"valid"`
	Status             int              `json:"status"`
	Receipt            map[string]any   `json:"receipt,omitempty"`
	LatestReceiptInfo  []map[string]any `json:"latest_receipt_info,omitempty"`
	PendingRenewalInfo []map[string]any `json:"pending_renewal_info,omitempty"`
	Error              string           `json:"error,omitempty"`
}

func verifyReceipt(receiptData, sharedSecret string, useSandbox bool) (*AppleResponse, error) {
	url := ProductionURL
	if useSandbox {
		url = SandboxURL
	}

	payload := AppleVerifyPayload{
		ReceiptData:            receiptData,
		ExcludeOldTransactions: true,
	}

	if sharedSecret != "" {
		payload.Password = sharedSecret
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var result AppleResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	if result.Status == 21007 {
		return verifyReceipt(receiptData, sharedSecret, true)
	}

	return &result, nil
}

func getStatusMessage(status int) string {
	messages := map[int]string{
		0:     "Valid receipt",
		21000: "The App Store could not read the JSON object",
		21002: "The receipt-data property was malformed or missing",
		21003: "The receipt could not be authenticated",
		21004: "The shared secret does not match",
		21005: "The receipt server is not currently available",
		21006: "Valid but subscription has expired",
		21007: "This receipt is from the test environment",
		21008: "This receipt is from the production environment",
		21009: "Internal data access error",
		21010: "User account cannot be found or has been deleted",
	}

	if msg, ok := messages[status]; ok {
		return msg
	}
	return fmt.Sprintf("Unknown status code: %d", status)
}

func verifyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req VerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Missing receipt data", http.StatusBadRequest)
		return
	}

	result, err := verifyReceipt(req.Receipt, req.SharedSecret, req.Sandbox)
	if err != nil {
		resp := VerifyResponse{
			Valid:  false,
			Status: -1,
			Error:  err.Error(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(resp)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	if result.Status == 0 {
		resp := VerifyResponse{
			Valid:              true,
			Status:             result.Status,
			Receipt:            result.Receipt,
			LatestReceiptInfo:  result.LatestReceiptInfo,
			PendingRenewalInfo: result.PendingRenewalInfo,
		}
		json.NewEncoder(w).Encode(resp)
	} else {
		resp := VerifyResponse{
			Valid:  false,
			Status: result.Status,
			Error:  getStatusMessage(result.Status),
		}
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(resp)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Countent-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func main() {
	http.HandleFunc("/verify", verifyHandler)
	http.HandleFunc("/health", healthHandler)

	port := ":3000"
	fmt.Printf("Apple IAP validation server runnning on port %s\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		fmt.Printf("Error starting server: %s\n", err)
	}
}
