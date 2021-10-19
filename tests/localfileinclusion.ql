/**
 * @id DEVAA-01
 * @description Path traversal, Local file inclusion security bugs via Content Provider
 * @kind problem
 */

import java

from RefType type
where type.getASupertype+().hasQualifiedName("android.content", "ContentProvider")
select type, "Path traversal, Local file inclusion security bugs via Content Provider"