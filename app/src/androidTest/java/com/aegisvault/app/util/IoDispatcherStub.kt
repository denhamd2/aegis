package com.aegisvault.app.util

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers

object IoDispatcherStub {
    val dispatcher: CoroutineDispatcher = Dispatchers.IO
}
