from flask import Flask, request, jsonify
import requests
import base64

app = Flask(__name__)

# Apple's verification endpoints
SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt"
PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt"


def verify_receipt(receipt_data, shared_secret=None, sandbox=False):
    """
    Verify an Apple IAP receipt

    Args:
        receipt_data: Base64 encoded receipt data
        shared_secret: Your app's shared secret (for auto-renewable subscriptions)
        sandbox: Whether to use sandbox environment

    Returns:
        dict: Verification response from Apple
    """
    url = SANDBOX_URL if sandbox else PRODUCTION_URL

    payload = {"receipt-data": receipt_data}

    if shared_secret:
        payload["password"] = shared_secret

    # Exclude unneeded data to reduce response size
    payload["exclude-old-transactions"] = True

    try:
        response = requests.post(url, json=payload, timeout=10)
        response.raise_for_status()
        data = response.json()

        # Status code 21007 means sandbox receipt sent to production
        # Automatically retry with sandbox
        if data.get("status") == 21007:
            response = requests.post(SANDBOX_URL, json=payload, timeout=10)
            response.raise_for_status()
            data = response.json()

        return data

    except requests.exceptions.RequestException as e:
        return {"error": str(e), "status": -1}


@app.route("/verify", methods=["POST"])
def verify():
    """
    Endpoint to verify receipt

    Expected JSON body:
    {
        "receipt": "base64_encoded_receipt_data",
        "shared_secret": "optional_shared_secret",
        "sandbox": false
    }
    """
    data = request.get_json()

    if not data or "receipt" not in data:
        return jsonify({"error": "Missing receipt data"}), 400

    receipt = data["receipt"]
    shared_secret = data.get("shared_secret")
    sandbox = data.get("sandbox", False)

    result = verify_receipt(receipt, shared_secret, sandbox)

    # Status codes:
    # 0 = valid
    # 21000-21010 = various errors
    status = result.get("status", -1)

    if status == 0:
        return jsonify(
            {
                "valid": True,
                "status": status,
                "receipt": result.get("receipt"),
                "latest_receipt_info": result.get("latest_receipt_info"),
                "pending_renewal_info": result.get("pending_renewal_info"),
            }
        )
    else:
        return jsonify(
            {"valid": False, "status": status, "error": get_status_message(status)}
        ), 400


def get_status_message(status):
    """Get human-readable status message"""
    messages = {
        0: "Valid receipt",
        21000: "The App Store could not read the JSON object you provided",
        21002: "The data in the receipt-data property was malformed or missing",
        21003: "The receipt could not be authenticated",
        21004: "The shared secret you provided does not match",
        21005: "The receipt server is not currently available",
        21006: "This receipt is valid but the subscription has expired",
        21007: "This receipt is from the test environment",
        21008: "This receipt is from the production environment",
        21009: "Internal data access error",
        21010: "The user account cannot be found or has been deleted",
    }
    return messages.get(status, f"Unknown status code: {status}")


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000, debug=True)
