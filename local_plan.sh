terraform plan -out plan.out

terraform show -json plan.out | jq . > plan.json


jq -r '
  .resource_changes[] |
  select(.change.actions | length > 0) |
  {
    action: (if .change.actions == ["delete", "create"] then "replace"
             else .change.actions[0] end),
    address: .address
  } | "\(.action) \(.address)"
' plan.json |
sort -t ' ' -k2,1 |
while read -r action address; do
  case $action in
    "create")  echo "\033[32m+ $address\033[0m" ;;  # green
    "update")  echo "\033[33m~ $address\033[0m" ;;  # yellow
    "delete")  echo "\033[31m- $address\033[0m" ;;  # red
    "replace") echo "\033[34m± $address\033[0m" ;;  # blue
  esac
done

rm plan.out plan.json