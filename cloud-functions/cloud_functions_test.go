package cloud_functions

import (
	"encoding/json"
	"fmt"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize_finalization"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/deploy"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/fetch"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/resize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/scale_down"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/scale_up"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/status"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/terminate"
	"os"
	"testing"
	"time"
)

func Test_bunch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	bucket := "weka-poc-state"
	err := clusterize_finalization.ClusterizeFinalization(project, zone, instanceGroup, bucket)
	if err != nil {
		t.Log("bunch test passed")
	} else {
		t.Logf("bunch test failed: %s", err)
	}
}

func Test_clusterize(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	hostsNum := "5"
	nicsNum := "4"
	gws := "(10.0.0.1 10.1.0.1 10.2.0.1 10.3.0.1)"
	clusterName := "poc"
	nvmesNumber := "2"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"
	clusterizeFinalizationUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-clusterize-finalization"

	bucket := "weka-poc-wekaio-rnd-state"
	instanceName := "weka-poc-vm-test"

	fmt.Printf("res:%s", clusterize.Clusterize(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesNumber, usernameId, passwordId, bucket, instanceName, clusterizeFinalizationUrl))
}

func Test_fetch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	bucket := "weka-poc-state"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"

	result, err := fetch.GetFetchDataParams(project, zone, instanceGroup, bucket, usernameId, passwordId)
	if err != nil {
		fmt.Println(err)
		return
	}
	b, err := json.Marshal(result)
	if err != nil {
		fmt.Println(err)
		return
	}

	t.Logf("res:%s", string(b))
}

func Test_deploy(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"
	tokenId := "projects/896245720241/secrets/weka-poc-token/versions/1"
	joinFinalizationUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-join-finalization"
	nicNum := 3
	bashScript, err := deploy.GetJoinParams(project, zone, instanceGroup, usernameId, passwordId, joinFinalizationUrl, nicNum)
	if err != nil {
		t.Logf("Generating join scripts failed: %s", err)
		return
	} else {
		t.Logf("%s", bashScript)
	}

	token := os.Getenv("GET_WEKA_IO_TOKEN")
	version := "4.0.1.37-gcp"

	bucket := "weka-poc-state"
	installUrl := fmt.Sprintf("https://%s@get.weka.io/dist/v1/install/%s/%s", token, version, version)
	clusterizeUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-clusterize"

	bashScript, err = deploy.GetDeployScript(project, zone, instanceGroup, usernameId, passwordId, tokenId, bucket, installUrl, clusterizeUrl, joinFinalizationUrl, 3)
	if err != nil {
		t.Logf("Generating deploy scripts failed: %s", err)
	} else {
		t.Logf("%s", bashScript)
	}

}

func Test_calculateDeactivateTarget(t *testing.T) {
	type args struct {
		nHealthy      int
		nUnhealthy    int
		nDeactivating int
		desired       int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{"manualDeactivate", args{9, 0, 1, 10}, 1},
		{"downscale", args{20, 0, 0, 10}, 10},
		{"downscaleP2", args{10, 0, 6, 10}, 6},
		{"downfailures", args{8, 2, 6, 10}, 6},
		{"failures", args{20, 10, 0, 30}, 2},
		{"failuresP2", args{20, 8, 2, 30}, 2},
		{"upscale", args{20, 0, 0, 30}, 0},
		{"upscaleFailures", args{20, 3, 0, 30}, 2},
		{"totalfailure", args{0, 20, 0, 30}, 2},
		{"totalfailureP2", args{0, 18, 2, 30}, 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := scale_down.CalculateDeactivateTarget(tt.args.nHealthy, tt.args.nUnhealthy, tt.args.nDeactivating, tt.args.desired); got != tt.want {
				t.Errorf("CalculateDeactivateTarget() = %v, want %v", got, tt.want)
			}
		})
	}
}

func Test_scaleUp(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	clusterName := "poc"
	instanceName := "weka-poc-vm-test"
	backendTemplate := "projects/wekaio-rnd/global/instanceTemplates/weka-poc-backends"
	scale_up.CreateInstance(project, zone, backendTemplate, instanceName)
	instances := common.GetInstancesByClusterLabel(project, zone, clusterName)
	instanceGroupSize := len(instances)
	t.Logf("Instance group size is: %d", instanceGroupSize)
	for _, instance := range instances {
		t.Logf("%s:%s", *instance.Name, *instance.Status)
	}
}

func Test_Terminate(t *testing.T) {
	_, err := time.Parse(time.RFC3339, "2022-06-21T21:59:55.156-07:00")

	if err != nil {
		t.Logf("error formatting creation time %s", err.Error())
	} else {
		t.Log("Formatting succeeded")
	}

	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-poc-instance-group"
	loadBalancerName := "weka-poc-lb-backend"

	errs := terminate.TerminateUnhealthyInstances(project, zone, instanceGroup, loadBalancerName)

	if len(errs) > 0 {
		t.Logf("error calling TerminateUnhealthyInstances %s", errs)
	} else {
		t.Log("TerminateUnhealthyInstances succeeded")
	}

	fmt.Println("ToDo: write test")
}

func Test_Transient(t *testing.T) {
	fmt.Println("ToDo: write test")
}

func Test_resize(t *testing.T) {
	bucket := "weka-poc-state"
	newDesiredValue := 6
	resize.UpdateValue(bucket, newDesiredValue)
}

func Test_status(t *testing.T) {
	// This will pass only before clusterization, after clusterization it will fail trying to fetch weka status
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	bucket := "weka-poc-wekaio-rnd"
	instanceGroup := "weka-poc-instance-group"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"

	clusterStatus, err := status.GetClusterStatus(project, zone, bucket, instanceGroup, usernameId, passwordId)
	if err != nil {
		t.Logf("Failed getting status %s", err)
	} else {
		clusterStatusJson, err := json.Marshal(clusterStatus)
		if err != nil {
			t.Logf("Failed decoding status %s", err)
		}
		fmt.Println(string(clusterStatusJson))
	}
}
