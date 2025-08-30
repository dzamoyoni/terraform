MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
/etc/eks/bootstrap.sh ${cluster_name}%{ if enable_prefix_delegation } --use-max-pods false%{ endif }%{ if max_pods > 0 && enable_prefix_delegation } --kubelet-extra-args '--max-pods=${max_pods}'%{ endif }

--BOUNDARY--
