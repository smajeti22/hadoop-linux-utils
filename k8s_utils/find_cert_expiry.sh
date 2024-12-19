kubectl get secrets -A |grep cert| while read -r namespace name rest; do
  # Skip header line
  if [[ "$namespace" == "NAMESPACE" ]]; then continue; fi

  echo "Checking secret: $name (Namespace: $namespace)"
  
  # Extract all keys under .data for the current secret
  keys=$(kubectl get secret "$name" -n "$namespace" -o jsonpath="{.data}" | jq -r 'keys[]')
  
  for key in $keys; do
    escaped_key=$(echo "$key" | sed 's/\./\\./g') # Escape dots in the key
    echo "  Key: $key"
    
    # Fetch and decode the value for the escaped key
    value=$(kubectl get secret "$name" -n "$namespace" -o jsonpath="{.data.$escaped_key}" | base64 --decode 2>/dev/null)
    
    # Check if the value is empty
    if [[ -z "$value" ]]; then
      echo "    Value is empty!"
    else
      # Extract certificate details (expiry and key ID) if the value is a valid certificate
      cert_info=$(echo "$value" | openssl x509 -noout -enddate -subject -fingerprint 2>/dev/null)

      if [[ $? -eq 0 ]]; then
        # Extract expiry date and key ID (fingerprint)
        expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d "=" -f 2)
        key_id=$(echo "$cert_info" | grep "SHA1 Fingerprint" | cut -d "=" -f 2 | tr -d ":")

        echo "    Expiry Date: $expiry_date"
        echo "    Key ID: $key_id"
      else
        echo "    Not a valid certificate or no expiry date found."
      fi
    fi
  done
done
