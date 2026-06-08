package com.fastcat.app;

import android.app.Application
import android.content.Context

class ApexApplication : Application() {
    companion object {
        private lateinit var instance: ApexApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}
