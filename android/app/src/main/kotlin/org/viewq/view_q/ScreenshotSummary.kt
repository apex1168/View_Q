package org.viewq.view_q

internal data class ScreenshotSummary(val category: String, val summary: String, val facts: String) {
    companion object {
        private fun pattern(value: String) = Regex(value, RegexOption.IGNORE_CASE)
        private val url = pattern("""(?:https?://|www\.)[^\s<>]+""")
        private val amount = pattern("""(?:[$€£₹]|\b(?:USD|INR|EUR|GBP|Rs\.?)\s*)\s*\d[\d,.]*""")
        private val reference = pattern("""\b(order|invoice|receipt|booking|tracking|reference|transaction|pnr|awb)\s*(?:id|no\.?|number|#|:)\s*[:#]?\s*([A-Z0-9-]{3,})""")
        private val date = pattern("""\b(?:\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b""")
        private val code = pattern("""\b(otp|verification code|one.time (?:password|code)|security code)\b""")
        private val noise = pattern("""^(?:\d{1,2}:\d{2}(?:\s*[AP]M)?|\d{1,3}%|LTE|[45]G|home|back|search|menu|settings|share|cancel|done|next|open|ok)(?:\s+(?:\d{1,3}%|LTE|[45]G))*$""")
        private val action = pattern("""\b(due|total|paid|delivered|scheduled|appointment|deadline|confirmed|cancelled|expires|departure|arrival|balance|tracking)\b""")
        private val mappings = listOf(
            "Travel" to pattern("""\b(pnr|boarding pass|departure|arrival|flight|train ticket|boarding gate|itinerary)\b"""),
            "Deliveries" to pattern("""\b(tracking number|tracking id|out for delivery|shipped|delivered|courier|shipment|awb)\b"""),
            "Payments" to pattern("""\b(transaction id|upi|payment successful|amount debited|amount credited|bank transfer)\b"""),
            "Receipt" to pattern("""\b(invoice|receipt|subtotal|grand total|amount paid|tax invoice|order total)\b"""),
            "Events" to pattern("""\b(appointment|rsvp|webinar|event registration|meeting invitation|scheduled for)\b"""),
            "Conversations" to pattern("""(?:\b(?:whatsapp|telegram|messenger|sent from my|subject:|reply to)\b|^From:\s)"""),
            "Documents" to pattern("""\b(page \d+ of \d+|certificate|statement of|application form|agreement|terms and conditions)\b"""),
        )

        fun from(text: String): ScreenshotSummary {
            if (text.isBlank()) return ScreenshotSummary("", "", "")
            if (code.containsMatchIn(text)) return ScreenshotSummary("OTP", "Verification message", "")
            val clean = text.lineSequence().take(400)
                .map { it.trim().replace(Regex("\\s+"), " ") }
                .filter { it.any(Char::isLetterOrDigit) && !noise.matches(it) }
                .distinctBy { it.lowercase() }.toList()
            val analyzed = clean.joinToString("\n")
            val links = url.findAll(analyzed).take(3).map { it.value.trimEnd('.', ',', ')') }.toList()
            val kind = mappings.firstOrNull { it.second.containsMatchIn(analyzed) }?.first
                ?: if (links.isNotEmpty()) "Link" else "Note"
            val amounts = amount.findAll(analyzed).take(4).map { it.value }.toList()
            val refs = reference.findAll(analyzed).take(4).map { it.value }.toList()
            val dates = date.findAll(analyzed).take(3).map { it.value }.toList()
            val facts = (refs + amounts + dates + links).distinct().take(6)
            val lines = clean.withIndex().filter { (_, line) ->
                !url.matches(line) && line.count { it.isLetter() } >= 5
            }.sortedByDescending { (i, line) ->
                val keyDetails = (if (action.containsMatchIn(line)) 14 else 0) +
                    (if (amount.containsMatchIn(line) || date.containsMatchIn(line)) 8 else 0) +
                    (if (reference.containsMatchIn(line)) 5 else 0)
                keyDetails + line.split(' ').count { it.length > 2 }.coerceAtMost(12) + if (i == 0) 6 else 0
            }.take(3).sortedBy { it.index }.map { (_, line) ->
                if (line.length <= 145) line else line.take(144).substringBeforeLast(' ', line.take(144)) + "…"
            }
            return ScreenshotSummary(kind, lines.joinToString("\n"), facts.joinToString("\n"))
        }
    }
}
