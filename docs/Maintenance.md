# Maintenance

## Adding Nodes

To add one or more nodes to a node pool, simply update the instance count in the configuration file for that node pool and run the create command again.

## Scaling Down a Node Pool

To reduce the size of a node pool:

1. Lower the instance count in the configuration file to ensure the extra nodes are not recreated in the future.
2. Drain and delete the additional nodes from Kubernetes. These are typically the last nodes when sorted alphabetically by name (`kubectl drain Node` followed by `kubectl delete node <name>`).
3. Remove the corresponding instances from the cloud console if the Cloud Controller Manager doesn’t handle this automatically. Make sure you delete the correct ones!

## Replacing a Problematic Node

1. Drain and delete the node from Kubernetes (`kubectl drain <name>` followed by `kubectl delete node <name>`).
2. Delete the correct instance from the cloud console.
3. Run the `create` command again. This will recreate the missing node and add it to the cluster.

## Converting a Non-HA Cluster to HA

Converting a single-master, non-HA cluster to a multi-master HA cluster is straightforward. Increase the masters instance count and rerun the `create` command. This will set up a load balancer for the API server (if enabled) and update the kubeconfig to direct API requests through the load balancer or one of the master contexts. For production clusters, it’s also a good idea to place the masters in different locations (refer to [this page](Masters_in_different_locations.md) for more details).

## Replacing the Seed Master

In a new HA cluster, the seed master (or first master) is `master1`. If you delete `master1` due to issues and it gets recreated, the seed master will change. When this happens, restart k3s on the existing masters.

---

## Upgrading to a New Version of k3s

For the first upgrade of your cluster, simply run the following command to update to a newer version of k3s:

```bash
hetzner-k3s upgrade --config cluster_config.yaml --new-k3s-version v1.27.1-rc2+k3s1
```

Specify the new k3s version as an additional parameter, and the configuration file will be updated automatically during the upgrade. To view available k3s releases, run the command `hetzner-k3s releases`.

Note: For single-master clusters, the API server will be briefly unavailable during the control plane upgrade.

To monitor the upgrade progress, use `watch kubectl get nodes -owide`. You will see the masters upgrading one at a time, followed by the worker nodes.

### What to Do If the Upgrade Doesn’t Go Smoothly

If the upgrade stalls or doesn’t complete for all nodes:

1. Clean up existing upgrade plans and jobs, then restart the upgrade controller:

```bash
kubectl -n system-upgrade delete job --all
kubectl -n system-upgrade delete plan --all

kubectl label node --all plan.upgrade.cattle.io/k3s-server- plan.upgrade.cattle.io/k3s-agent-

kubectl -n system-upgrade rollout restart deployment system-upgrade-controller
kubectl -n system-upgrade rollout status deployment system-upgrade-controller
```

You can also check the logs of the system upgrade controller’s pod:

```bash
kubectl -n system-upgrade \
  logs -f $(kubectl -n system-upgrade get pod -l pod-template-hash -o jsonpath="{.items[0].metadata.name}")
```

If the upgrade stalls after upgrading the masters but before upgrading the worker nodes, simply cleaning up resources might not be enough. In this case, run the following to mark the masters as upgraded and allow the upgrade to continue for the workers:

```bash
kubectl label node <master1> <master2> <master2> plan.upgrade.cattle.io/k3s-server=upgraded
```

Once all the nodes have been upgraded, remember to re-run the `hetzner-k3s create` command. This way, new nodes will be created with the new version right away. If you don’t, they will first be created with the old version and then upgraded by the system upgrade controller.

---

## Upgrading the OS on Nodes

1. Consider adding a temporary node during the process if your cluster doesn’t have enough spare capacity.
2. Drain one node.
3. Update the OS and reboot the node.
4. Uncordon the node.
5. Repeat for the next node.

To automate this process, you can install the [Kubernetes Reboot Daemon](https://kured.dev/) ("Kured"). For Kured to work effectively, ensure the OS on your nodes has unattended upgrades enabled, at least for security updates. For example, if the image is Ubuntu, add this to the configuration file before running the `create` command:

```yaml
additional_packages:
- unattended-upgrades
- update-notifier-common
additional_post_k3s_commands:
- sudo systemctl enable unattended-upgrades
- sudo systemctl start unattended-upgrades
```

Refer to the Kured documentation for additional configuration options, such as maintenance windows.
