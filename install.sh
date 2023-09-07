#!/bin/bash


# Run k3d cluster list and capture its output
cluster_list_output=$(k3d cluster list)

# Check if the k3d command was successful
if [ $? -eq 0 ]; then
  # Check if the cluster list output contains the name of your cluster
  if echo "$cluster_list_output" | grep -q "local-argo"; then
    echo "Your cluster is running."
  else
    echo "Your cluster is not running."
  fi
else
  echo "Error: Unable to run 'k3d cluster list'. Make sure k3d is installed and configured."
fi


