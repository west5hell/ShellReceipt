const express = require("express");
const axios = require("axios");

const app = express();
app.use(express.json());

const SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";
const PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt";

/**
 * Verify an Apple IAP receipt
 */
async function verifyReceipt(
  receiptData,
  sharedSecret = null,
  useSandbox = false
) {
  const url = useSandbox ? SANDBOX_URL : PRODUCTION_URL;

  const payload = {
    "receipt-data": receiptData,
    "exclude-old-transactions": true,
  };

  if (sharedSecret) {
    payload.password = sharedSecret;
  }

  try {
    const response = await axios.post(url, payload, {
      timeout: 10000,
      headers: { "Content-Type": "application/json" },
    });

    const data = response.data;

    // Status 21007: sandbox receipt sent to production, retry with sandbox
    if (data.status === 21007) {
      const retryResponse = await axios.post(SANDBOX_URL, payload, {
        timeout: 10000,
        headers: { "Content-Type": "application/json" },
      });
      return retryResponse.data;
    }

    return data;
  } catch (error) {
    return {
      error: error.message,
      status: -1,
    };
  }
}

/**
 * Get human-readable status message
 */
function getStatusMessage(status) {
  const messages = {
    0: "Valid receipt",
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
  };
  return messages[status] || `Unknown status code: ${status}`;
}

/**
 * POST /verify - Verify receipt endpoint
 *
 * Body:
 * {
 *   "receipt": "base64_encoded_receipt",
 *   "shared_secret": "optional_secret",
 *   "sandbox": false
 * }
 */
app.post("/verify", async (req, res) => {
  const { receipt, shared_secret, sandbox = false } = req.body;

  if (!receipt) {
    return res.status(400).json({ error: "Missing receipt data" });
  }

  const result = await verifyReceipt(receipt, shared_secret, sandbox);

  const status = result.status ?? -1;

  if (status === 0) {
    return res.json({
      valid: true,
      status: status,
      receipt: result.receipt,
      latest_receipt_info: result.latest_receipt_info,
      pending_renewal_info: result.pending_renewal_info,
    });
  } else {
    return res.status(400).json({
      valid: false,
      status: status,
      error: getStatusMessage(status),
    });
  }
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Apple IAP validation server running on port ${PORT}`);
});

module.exports = app;
