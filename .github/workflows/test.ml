name: Kubernetes Network Test

on:
  workflow_dispatch:
    inputs:
      cluster_option:
        description: "Cluster location (1=ashburn, 2=hillsboro)"
        required: true
        default: "1"
      host_name:
        description: "Target host name"
        required: true
      port_number:
        description: "Target port number"
        required: true
      network_command:
        description: "Network command (1=curl, 2=traceroute, 3=both)"
        required: true
        default: "1"
      token:
        description: "Kubernetes token"
        required: true

jobs:
  run-network-test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set cluster variables
        id: set-cluster
        run: |
          if [ "${{ github.event.inputs.cluster_option }}" == "1" ]; then
            echo "CLUSTER_NAME=ashburn-rdei-01-maas-proxy" >> $GITHUB_ENV
            echo "SERVER=ashburn-rdei-01.ashburn-rdei.rdei.comcast.net" >> $GITHUB_ENV
          elif [ "${{ github.event.inputs.cluster_option }}" == "2" ]; then
            echo "CLUSTER_NAME=hillsboro-rdei-01-maas-proxy" >> $GITHUB_ENV
            echo "SERVER=hillsboro-rdei-01.hillsboro-rdei.rdei.comcast.net" >> $GITHUB_ENV
          else
            echo "Invalid cluster option"
            exit 1
          fi

      - name: Configure kubectl
        run: |
          kubectl config set-cluster $CLUSTER_NAME --server=https://$SERVER:6443 --insecure-skip-tls-verify
          kubectl config set-credentials $CLUSTER_NAME --token=${{ github.event.inputs.token }} --insecure-skip-tls-verify
          kubectl config set-context $CLUSTER_NAME --cluster=$CLUSTER_NAME --namespace=maas-proxy --user=$CLUSTER_NAME --insecure-skip-tls-verify
          kubectl config use-context $CLUSTER_NAME --insecure-skip-tls-verify

      - name: Get pod name
        id: pod
        run: |
          POD_NAME=$(kubectl get pods | grep 'metrics-cnivip' | awk '{print $1}')
          echo "POD_NAME=$POD_NAME" >> $GITHUB_ENV

      - name: Run network command
        run: |
          if [ "${{ github.event.inputs.network_command }}" == "1" ]; then
            kubectl exec -it $POD_NAME -- curl -v http://${{ github.event.inputs.host_name }}:${{ github.event.inputs.port_number }}/metrics
          elif [ "${{ github.event.inputs.network_command }}" == "2" ]; then
            kubectl exec -it $POD_NAME -- traceroute -I ${{ github.event.inputs.host_name }} -p ${{ github.event.inputs.port_number }}
          elif [ "${{ github.event.inputs.network_command }}" == "3" ]; then
            kubectl exec -it $POD_NAME -- curl -v http://${{ github.event.inputs.host_name }}:${{ github.event.inputs.port_number }}/metrics
            kubectl exec -it $POD_NAME -- traceroute -I ${{ github.event.inputs.host_name }} -p ${{ github.event.inputs.port_number }}
          else
            echo "Invalid option. Please enter 1 for curl, 2 for traceroute, or 3 for both."
            exit 1
          fi
