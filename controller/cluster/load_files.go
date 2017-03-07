package cluster

import (
	"fmt"
	"path"

	"github.com/kubermatic/api"
	"github.com/kubermatic/api/controller/template"
	"k8s.io/client-go/pkg/api/v1"
	extensionsv1beta1 "k8s.io/client-go/pkg/apis/extensions/v1beta1"
)

func loadServiceFile(cc *clusterController, c *api.Cluster, s string) (*v1.Service, error) {
	t, err := template.ParseFiles(path.Join(cc.masterResourcesPath, s+"-service.yaml"))
	if err != nil {
		return nil, err
	}

	var service v1.Service

	data := struct {
		Cluster *api.Cluster
	}{
		Cluster: c,
	}

	err = t.Execute(data, &service)

	return &service, err
}

func loadIngressFile(cc *clusterController, c *api.Cluster, s string) (*extensionsv1beta1.Ingress, error) {
	t, err := template.ParseFiles(path.Join(cc.masterResourcesPath, s+"-ingress.yaml"))
	if err != nil {
		return nil, err
	}
	var ingress extensionsv1beta1.Ingress
	data := struct {
		DC          string
		ClusterName string
		ExternalURL string
	}{
		DC:          cc.dc,
		ClusterName: c.Metadata.Name,
		ExternalURL: cc.externalURL,
	}
	err = t.Execute(data, &ingress)

	if err != nil {
		return nil, err
	}

	return &ingress, err
}

func loadPVCFile(cc *clusterController, c *api.Cluster, s string) (*v1.PersistentVolumeClaim, error) {
	t, err := template.ParseFiles(path.Join(cc.masterResourcesPath, s+"-pvc.yaml"))
	if err != nil {
		return nil, err
	}

	var pvc v1.PersistentVolumeClaim
	data := struct {
		ClusterName string
	}{
		ClusterName: c.Metadata.Name,
	}
	err = t.Execute(data, &pvc)
	return &pvc, err
}

func loadAwsCloudConfigConfigMap(cc *clusterController, c *api.Cluster, s string) (*v1.ConfigMap, error) {
	cm := v1.ConfigMap{}
	cm.Name = "aws-cloud-config"
	cm.APIVersion = "v1"
	cm.Data = map[string]string{
		"aws-cloud-config": fmt.Sprintf(`
[global]
zone=%s
kubernetesclustertag=
disablesecuritygroupingress=false
disablestrictzonecheck=true`, c.Spec.Cloud.AWS.AvailabilityZone),
	}
	return &cm, nil

}
