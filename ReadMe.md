**CrashLoopBackOff - Cleaner App**


![image](https://user-images.githubusercontent.com/20109548/230361668-e9c8e369-22df-4c3f-90aa-d67471fa573d.png)


This is implemented as a temporary solution to the issue [Intermittent CrashLoopBackOff in Windows Containers Running on AKS (.NET 6 Apps with System.Net.Sockets.SocketException 11001 and 10060)](https://github.com/Azure/AKS/issues/3598). Same issue is asked in [stackoverflow here](https://stackoverflow.com/questions/75928226/intermittent-crashloopbackoff-in-windows-containers-running-on-aks-net-6-apps).

Instead of manually deleting pods that run into the issue maually, the cleaner app implemented in this repo is doing automatic deletion of pods CrashLoopBackOff state with known exception reported in the container log. If the exeception is unknown the pod in CrashLoopBackOff state will not be deleted, and the container log output is printed, in cleaner app logs to show the exception of the pod having CrashLoopBackOff state.

To get the CrashLoopBackOff cleaner app deployed to AKS follow the below steps.

- Clone the repo from GitHub.
- Copy content of `cleanerapp/cleaner.sh` and 'cleanerapp/setup.sh' to a text editor. Then delete the two files and create them as new files with same name. Then copy back the content these two .sh files. This is to avoid issues such as `curl: Failed to extract a sensible file name from the URL to use for storage!` when executing the two files with docker build and run. 
- Replace `AzureSPNAppId`,`AzureSPNAppPwd`,`AzureTenantId`,`AzureSubscriptionId`,`aksCusterName` and `aksClusterResourceGroupName` in cleanerapp/setup.sh
- Replace `appconfigsvcname` and `aksnamespace` in cleanerapp/cleaner.sh
- `docker build -t cleanerapp:dev .`
- `docker tag cleanerapp:dev youracr.azurecr.io/demo/crashloopbackoffcleaner:latest`
- [Push the tagged docker image to Azure Container Registry](http://chamindac.blogspot.com/2022/09/manually-push-net-app-docker-image-to.html)
- Use makefiles and k8s.yaml files in deploy folder to get the app deployed to AKS Linux node.


**Note**: This workaround solution is implemented for a .NET 6 application having a single container running in each pod, running into socket exceptions at startup, while trying to connect to Azure App Configuration service.

Issue description is below..

**Intermittent CrashLoopBackOff in Windows Containers Running on AKS (.NET 6 Apps with System.Net.Sockets.SocketException 11001 and 10060)**

I am running .NET 6 apps in AKS. Have 11 Linux based apps and 11 Windows based apps (due to legency dependency on c++ library which is depending on Windows patform). Once a deployment of all 22 Apps done via parellel running Azure DevOps pipelines, which are using Kubernetes manifest files to deploy each app, apps were giving intermittenet CrashLoopBackOff randomly. One or two apps randomly fail at starting up. Each of these app is in a seperate pod. some apps have 2 minimum instances. Once a deployemnt done sometimes one instance starts fine, and one instance of same app may go to CrashLoopBackOff, trying to connect to Azure App Configuration service.

Analyzing log of CrashLoopBackOff container shown it fails connecting to Azure app config service, which is using a Azure Key Vault to keep secrets. The issue shown is one of the below.

**System.Net.Sockets.SocketException (10060): A connection attempt failed**
```
---> Azure.RequestFailedException: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond. (my-demo-dev-appconfig-ac.azconfig.io:443)
 ---> System.Net.Http.HttpRequestException: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond. (my-demo-dev-appconfig-ac.azconfig.io:443)
 ---> System.Net.Sockets.SocketException (10060): A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond.
```

**System.Net.Sockets.SocketException (11001): No such host is known.**
```
Unhandled exception. System.AggregateException: Retry failed after 3 tries. Retry settings can be adjusted in ClientOptions.Retry. (No such host is known. (my-demo-dev-appconfig-ac.azconfig.io:443)) (No such host is known. (my-demo-dev-appconfig-ac.azconfig.io:443)) (No such host is known. (my-demo-dev-appconfig-ac.azconfig.io:443))
 ---> Azure.RequestFailedException: No such host is known. (my-demo-dev-appconfig-ac.azconfig.io:443)
 ---> System.Net.Http.HttpRequestException: No such host is known. (my-demo-dev-appconfig-ac.azconfig.io:443)
 ---> System.Net.Sockets.SocketException (11001): No such host is known.
```


**Attempted Fixes**


Intially the issue was happening in both Windows and Linux containers. However, after making the following fix (dnsConfig) in Kubernetes deployment manifest the linux containers no longer giving any CrashLoopBackOff and all linux apps starts fine after a deployment or a rollover restart.

```
template:
    metadata:
      labels:
        app: ${aks_app_name}$
        service: ${aks_app_name}$
    spec:
      nodeSelector:
        "kubernetes.io/os": ${aks_app_nodeselector}$
      priorityClassName: ${aks_app_container_priorityclass_name}$
      #------------------------------------------------------
      # setting pod DNS policies to enable faster DNS resolution
      # https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy
      dnsConfig:
        options:
          # use FQDN everywhere 
          # any cluster local access from pods need full CNAME to resolve 
          # short names will not resolve to internal cluster domains
          - name: ndots
            value: "2"
          # dns resolver timeout and attempts
          - name: timeout
            value: "15"
          - name: attempts
            value: "3"
          # use TCP to resolve DNS instad of using UDP (UDP is lossy and pods need to wait for timeout for lost packets)
          - name: use-vc
          # open new socket for retrying
          - name: single-request-reopen
      #------------------------------------------------------
      volumes:
```

However, the windows containers still randomly run into this issue after a deployment most of the time. But have not seen this happening, when pods are scaling, due to load, based on horozontal pod autoscaler settings. In rollover restarts, the CrashLoopBackOff occurs rarely running the Windows containers with one of the above mentioned socket exceptions.

Following articles, github issues etc. already referred for this.

 - [https://medium.com/asos-techblog/an-aks-performance-journey-part-2-networking-it-out-e253f5bb4f69](https://medium.com/asos-techblog/an-aks-performance-journey-part-2-networking-it-out-e253f5bb4f69)
 - [https://youtu.be/XbkViBUuScE](https://youtu.be/XbkViBUuScE)
 - [https://blog.codacy.com/dns-hell-in-kubernetes/](https://blog.codacy.com/dns-hell-in-kubernetes/)
 - [https://github.com/kubernetes/kubernetes/issues/56903#issuecomment-359085202](https://github.com/kubernetes/kubernetes/issues/56903#issuecomment-359085202)
 - [https://man7.org/linux/man-pages/man5/resolv.conf.5.html](https://man7.org/linux/man-pages/man5/resolv.conf.5.html)

Setting up node local dns cache is not possible in AKS as by design AKS does not allow this. [https://github.com/Azure/AKS/issues/1435](https://github.com/Azure/AKS/issues/1435)

From .NET point of view following are referred.
 - [https://github.com/dotnet/runtime/issues/31247](https://github.com/dotnet/runtime/issues/31247)
 - [https://github.com/dotnet/runtime/issues/54547](https://github.com/dotnet/runtime/issues/54547)

Tried adding below code fixes to increase retries and delays between retries in the apps

```
    return configurationBuilder.AddAzureAppConfiguration(options =>
                {
                    options
                        .Connect(appConfigurationEndpoint)
                        .ConfigureClientOptions(clientOptions =>
                        {
                            clientOptions.Retry.Delay = TimeSpan.FromSeconds(10);
                            clientOptions.Retry.MaxDelay = TimeSpan.FromSeconds(40);
                            clientOptions.Retry.MaxRetries = 5;
                            clientOptions.Retry.Mode = RetryMode.Exponential;
                        });
```

```
SecretClientOptions secrteClientOptions = new()
                    {
                        Retry =
                        {
                            Delay= TimeSpan.FromSeconds(10),
                            MaxDelay = TimeSpan.FromSeconds(40),
                            MaxRetries = 5,
                            Mode = RetryMode.Exponential
                            }
                    };
```



But these retry delay etc. changes in app only resulted in, such failing container to take long time like 20 minutes to run into CrashLoopBackOff. Without above retry settings, such container (pod) runs into CrashLoopBackOff sooner with one of above socket exceptions. Sometimes when such a pod is left alone for longer time like 45 minutes to one hour it automatically manages to get up and running on the restart attempts by Kubernetes.

Any thoughts or ideas to apply as a fix for AKS or to the .NET app is helpful here as this CrashLoopBackOff is annoying. Now, what is being done is after a deployment, I check the AKS workloads, pods from Azure portal(or using kubectl) and kill the pod in crashloopback, which creates another pod by Kubernetes and that is running fine.
