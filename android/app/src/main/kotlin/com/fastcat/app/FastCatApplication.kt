package com.fastcat.app;

import android.app.Application
import android.content.Context

class FastCatApplication : Application() {
    companion object {
        private lateinit var instance: FastCatApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}
