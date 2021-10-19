/**
 * @id CWE-826-A
 * @description JavaScript rendered inside WebViews can access any protected application file and web resource from any origin
 * @kind problem
 */

import java

from MethodAccess ma
where
  ma.getMethod().getName().matches("loadDataWithBaseURL")
select ma, "JavaScript rendered inside WebViews can access any protected application file and web resource from any origin"