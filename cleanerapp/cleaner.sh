echo "Check kubectl version"
kubectl version --short

appConfigSvc="appconfigsvcname.azconfig.io"
namespace="aksnamespace"

while :
do
	allPods=$(kubectl get pods -n $namespace -o json | jq -r '.items[].metadata.name');
    noCrashFound=true;

    for eachPod in $allPods
    do
        podState=$(kubectl get pods $eachPod -n $namespace -o json | jq -r '.status.containerStatuses[0].state.waiting.reason');
        
        if [ "$podState" = "CrashLoopBackOff" ]
        then
            noCrashFound=false;
            echo "$eachPod is in $podState. Reading log to determine if known exception...";
            
            podLog=$(kubectl logs $eachPod -n $namespace --tail 5000);

            if [[ "${podLog}" == *"System.Net.Sockets.SocketException (11001): No such host is known."* \
                    && "${podLog}" == *"(No such host is known. ($appConfigSvc:443))"* ]] \
                || [[ "${podLog}" == *"System.Net.Sockets.SocketException (0xFFFDFFFF): Name or service not known"* \
                    && "${podLog}" == *"(Name or service not known ($appConfigSvc:443))"* ]] \
                || [[ "${podLog}" == *"System.Net.Sockets.SocketException (10060): A connection attempt failed"* \
                    && "${podLog}" == *"connected host has failed to respond. ($appConfigSvc:443))"* ]] 
            then
                echo "$eachPod is in $podState with a known exception. Terminating...";
                kubectl delete pods $eachPod -n $namespace                
            else 
                echo "$eachPod is in $podState with an unknown exception. Printing log...";
                echo $podLog;
            fi
        fi
    done
    
    if [ "$noCrashFound" = true ] ; then
        echo 'No CrashLoopBackOff pods found.'
    fi

	sleep 60
done