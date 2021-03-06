export MASTER_ENDPOINT="https://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2379"


# If we're already initialized
if [ -d "/var/run/etcd/pod_${POD_NAME}/" ]; then
    echo "we're already initialized"
    export INITIAL_STATE="existing"
    if [ "${POD_NAME}" = "etcd-0" ]; then
        export INITIAL_CLUSTER="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380"
    fi
    if [ "${POD_NAME}" = "etcd-1" ]; then
        export INITIAL_CLUSTER="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380,etcd-1=http://etcd-1.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380"
    fi
    if [ "${POD_NAME}" = "etcd-2" ]; then
        export INITIAL_CLUSTER="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380,etcd-1=http://etcd-1.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380,etcd-2=http://etcd-2.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380"
    fi
else
    if [ "${POD_NAME}" = "etcd-0" ]; then
        echo "i'm etcd-0. I do the restore"
        etcdctl --endpoints http://etcd-cluster-client:2379 snapshot save snapshot.db
        etcdctl snapshot restore snapshot.db \
            --name etcd-0 \
            --data-dir="/var/run/etcd/pod_${POD_NAME}/" \
            --initial-cluster="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380" \
            --initial-cluster-token="62m9k9tqlm" \
            --initial-advertise-peer-urls http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380
        echo "restored from snapshot"
        export INITIAL_STATE="new"
        export INITIAL_CLUSTER="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380"
    fi

    export ETCD_CERT_ARGS="--cacert /etc/etcd/pki/ca/ca.crt --cert /etc/etcd/pki/client/apiserver-etcd-client.crt --key /etc/etcd/pki/client/apiserver-etcd-client.key"
    if [ "${POD_NAME}" = "etcd-1" ]; then
        echo "i'm etcd-1. I join as new member as soon as etcd-0 comes up"
        etcdctl ${ETCD_CERT_ARGS} --endpoints ${MASTER_ENDPOINT} member add etcd-1 --peer-urls=http://etcd-1.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380
        echo "added etcd-1 to members"
        export INITIAL_STATE="existing"
        export INITIAL_CLUSTER="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380,etcd-1=http://etcd-1.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380"
    fi

    if [ "${POD_NAME}" = "etcd-2" ]; then
        echo "i'm etcd-2. I join as new member as soon as we have 2 existing & healthy members"
        until etcdctl ${ETCD_CERT_ARGS} --endpoints ${MASTER_ENDPOINT} member list | grep -q etcd-1; do sleep 1; echo "Waiting for etcd-1"; done
        etcdctl ${ETCD_CERT_ARGS} --endpoints ${MASTER_ENDPOINT} member add etcd-2 --peer-urls=http://etcd-2.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380
        echo "added etcd-2 to members"
        export INITIAL_STATE="existing"
        export INITIAL_CLUSTER="etcd-0=http://etcd-0.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380,etcd-1=http://etcd-1.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380,etcd-2=http://etcd-2.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380"
    fi
fi



echo "initial-state: ${INITIAL_STATE}"
echo "initial-cluster: ${INITIAL_CLUSTER}"

exec /usr/local/bin/etcd \
    --name=${POD_NAME} \
    --data-dir="/var/run/etcd/pod_${POD_NAME}/" \
    --initial-cluster=${INITIAL_CLUSTER} \
    --initial-cluster-token="62m9k9tqlm" \
    --initial-cluster-state=${INITIAL_STATE} \
    --advertise-client-urls "https://${POD_NAME}.etcd.cluster-62m9k9tqlm.svc.cluster.local:2379,https://${POD_IP}:2379" \
    --listen-client-urls "https://${POD_IP}:2379,https://127.0.0.1:2379" \
    --listen-peer-urls "http://${POD_IP}:2380" \
    --initial-advertise-peer-urls "http://${POD_NAME}.etcd.cluster-62m9k9tqlm.svc.cluster.local:2380" \
    --trusted-ca-file /etc/etcd/pki/ca/ca.crt \
    --client-cert-auth \
    --cert-file /etc/etcd/pki/tls/etcd-tls.crt \
    --key-file /etc/etcd/pki/tls/etcd-tls.key \
    --auto-compaction-retention=8
