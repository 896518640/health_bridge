# HMS SDK 混淆配置
-ignorewarnings
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Keep HMS classes
-keep class com.hianalytics.android.**{*;}
-keep class com.huawei.updatesdk.**{*;}
-keep class com.huawei.hms.**{*;}

# Keep Health Kit classes
-keep class com.huawei.hms.hihealth.**{*;}
-keep interface com.huawei.hms.hihealth.**{*;}

# Keep AGConnect
-keep class com.huawei.agconnect.**{*;}
-dontwarn com.huawei.agconnect.**

# Keep HMS Core
-keep class com.huawei.hmf.**{*;}
-keep class com.huawei.hms.framework.**{*;}
