package com.aegisvault.app.util

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestWatcher
import org.junit.runner.Description

/**
 * Exposes its dispatcher so tests can pass it into `runTest(mainDispatcherRule.testDispatcher)`.
 * That's required, not optional: `runTest {}` on its own creates its own TestCoroutineScheduler,
 * separate from whatever this rule sets as Dispatchers.Main — ViewModel coroutines launched on
 * Main would run on a scheduler the test's own advanceUntilIdle()/awaitItem() never advances.
 * Sharing one scheduler between the test body and Dispatchers.Main is what keeps them in sync.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    val testDispatcher: TestDispatcher = StandardTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) {
        kotlinx.coroutines.Dispatchers.setMain(testDispatcher)
    }

    override fun finished(description: Description) {
        kotlinx.coroutines.Dispatchers.resetMain()
    }
}
