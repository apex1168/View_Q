# Room opens this generated database via a reflected no-argument constructor.
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }

# WorkManager persists the worker class name and creates it reflectively.
-keep class org.viewq.view_q.OcrWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Tesseract JNI looks up its Java bindings by name.
-keep class com.googlecode.tesseract.android.** { *; }
-keep class com.googlecode.leptonica.android.** { *; }
