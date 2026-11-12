package com.example.aiphonecontroller

import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.runBlocking
import java.io.File
import java.util.concurrent.Executors

/**
 * Owns one LiteRT-LM engine and conversation on a single background thread.
 * Model weights are stored outside the APK in app-private external files.
 */
class OfflineAiRuntime(private val modelFile: File) {
    private val executor = Executors.newSingleThreadExecutor()
    private var engine: Engine? = null
    private var conversation: Conversation? = null
    @Volatile private var ready = false

    fun isReady(): Boolean = ready

    fun load(onComplete: (Boolean, String?) -> Unit) {
        executor.execute {
            if (ready) {
                onComplete(true, null)
                return@execute
            }
            if (!modelFile.isFile || modelFile.length() < 100_000_000L) {
                onComplete(false, "Offline model file is missing or incomplete.")
                return@execute
            }
            var createdEngine: Engine? = null
            var initialized = false
            try {
                val newEngine = Engine(EngineConfig(modelPath = modelFile.absolutePath))
                createdEngine = newEngine
                runBlocking { newEngine.initialize() }
                initialized = true
                val createdConversation = runBlocking {
                    newEngine.createConversation(
                        ConversationConfig(
                            systemInstruction = Contents.of(
                                "You are the offline assistant inside AI Phone Controller. " +
                                    "Help with ordinary Android tasks and general questions. Never claim you performed an action. " +
                                    "Do not help access weapons, drugs, intoxicants, gambling, pornography, or dangerous challenges, and never bypass age restrictions. " +
                                    "Do not request passwords, one-time codes, or payment credentials. " +
                                    "When asked for automation plans, output only the requested JSON."
                            ),
                            samplerConfig = SamplerConfig(topK = 40, topP = 0.9, temperature = 0.2),
                        )
                    )
                }
                engine = newEngine
                conversation = createdConversation
                ready = true
                onComplete(true, null)
            } catch (error: Throwable) {
                if (initialized) {
                    try { createdEngine?.close() } catch (_: Throwable) { }
                }
                onComplete(false, error.message ?: "Could not load the offline model.")
            }
        }
    }

    fun generate(prompt: String, onComplete: (String?, String?) -> Unit) {
        executor.execute {
            val activeConversation = conversation
            if (!ready || activeConversation == null) {
                onComplete(null, "Load the offline AI model first.")
                return@execute
            }
            try {
                val output = StringBuilder()
                runBlocking {
                    activeConversation.sendMessageAsync(prompt).collect { chunk ->
                        output.append(chunk.toString())
                    }
                }
                onComplete(output.toString().trim(), null)
            } catch (error: Throwable) {
                onComplete(null, error.message ?: "Offline AI generation failed.")
            }
        }
    }

    fun close() {
        executor.execute {
            try { conversation?.close() } catch (_: Throwable) { }
            conversation = null
            try { engine?.close() } catch (_: Throwable) { }
            engine = null
            ready = false
        }
        executor.shutdown()
    }
}
