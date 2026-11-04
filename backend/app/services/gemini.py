import json
import logging
import google.generativeai as genai
from typing import Dict, Any
from app.core.config import settings

logger = logging.getLogger("aquafix.gemini")
logging.basicConfig(level=logging.INFO)

VALID_CATEGORIES = {
    "Pipeline Leak",
    "Drainage Blockage",
    "Overflowing Sewage",
    "Road Sinkhole",
    "Public Sanitation Issue"
}

VALID_SEVERITIES = {"Low", "Medium", "High", "Critical"}

class GeminiVisionService:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.use_mock = not bool(self.api_key)
        
        if self.use_mock:
            logger.warning(
                "⚠️ GEMINI_API_KEY is not set. Falling back to local Mock Vision Validation service. "
                "Set GEMINI_API_KEY in backend/.env to activate live Gemini 1.5 Flash parsing."
            )
        else:
            genai.configure(api_key=self.api_key)
            self.model = genai.GenerativeModel("gemini-1.5-flash")

    async def verify_and_categorize_incident(self, image_bytes: bytes, mime_type: str = "image/jpeg") -> Dict[str, Any]:
        """
        Sends image binary payload to Gemini 1.5 Flash for visual verification (spam filtering),
        auto-categorization, severity estimation, and feature breakdown.
        
        Returns an advisory metadata dictionary:
        {
            "is_infrastructure_issue": bool,
            "category": str,
            "severity": str,
            "confidence": float,
            "reasoning": str,
            "visual_markers": [str]
        }
        """
        if self.use_mock:
            logger.info("🤖 [MOCK ENGINE] Simulating visual verification on incident image.")
            return {
                "is_infrastructure_issue": True,
                "category": "Pipeline Leak",
                "severity": "High",
                "confidence": 0.96,
                "reasoning": "Mock verification: Image shows pressurized clean water erupting from fractured pavement seam.",
                "visual_markers": ["water eruption", "fractured road pavement", "puddle accumulation"]
            }

        prompt = (
            "You are an expert municipal infrastructure auditor and public safety inspector.\n"
            "Analyze the uploaded image and perform four advisory tasks:\n"
            "1. SPAM FILTERING: Verify if the image depicts a public utility, municipal infrastructure, "
            "or public sanitation/water issue (e.g., broken water pipelines, overflowing drainage, sewage, "
            "flooded roads, sinkholes, public toilet issues).\n"
            "2. AUTO-CATEGORIZATION: Categorize into one of these strict categories:\n"
            "   - 'Pipeline Leak'\n"
            "   - 'Drainage Blockage'\n"
            "   - 'Overflowing Sewage'\n"
            "   - 'Road Sinkhole'\n"
            "   - 'Public Sanitation Issue'\n"
            "3. SEVERITY ESTIMATION: Suggest severity level from:\n"
            "   - 'Critical' (immediate danger to public health/safety, severe road collapse, major water main burst)\n"
            "   - 'High' (significant sewage overflow, active flooding, moderate sinkhole)\n"
            "   - 'Medium' (clogged storm drain, persistent pipe drip, non-emergency sanitation)\n"
            "   - 'Low' (minor cosmetic water issue, stagnant puddle, small litter/blockage)\n"
            "4. VISUAL MARKERS: List 2 to 4 key visual features observed in the photo.\n\n"
            "You MUST respond ONLY with a valid JSON block of this shape with NO markdown fences:\n"
            "{\n"
            "  \"is_infrastructure_issue\": true,\n"
            "  \"category\": \"Pipeline Leak\",\n"
            "  \"severity\": \"High\",\n"
            "  \"confidence\": 0.95,\n"
            "  \"reasoning\": \"Brief explanation of what visual markers verify this identification.\",\n"
            "  \"visual_markers\": [\"pressurized water flow\", \"cracked tarmac\", \"curbside ponding\"]\n"
            "}\n"
            "If the image is not a valid infrastructure issue (e.g. selfie, food, indoor furniture, random spam), "
            "set \"is_infrastructure_issue\" to false and specify the reasoning."
        )

        try:
            image_part = {
                "mime_type": mime_type,
                "data": image_bytes
            }

            response = self.model.generate_content(
                [prompt, image_part],
                generation_config=genai.types.GenerationConfig(
                    temperature=0.2,
                    top_p=0.95,
                    max_output_tokens=600
                )
            )
            
            if not response or not response.text:
                logger.error("Gemini returned empty response")
                raise ValueError("Empty response from Gemini API")
            
            text_response = response.text.strip()
            
            # Handle markdown fence code wrapper formatting if returned by LLM
            if text_response.startswith("```json"):
                text_response = text_response.split("```json")[1].split("```")[0].strip()
            elif text_response.startswith("```"):
                text_response = text_response.split("```")[1].split("```")[0].strip()

            result = json.loads(text_response)
            
            # Ensure required fields
            is_infra = bool(result.get("is_infrastructure_issue", False))
            category = result.get("category", "Public Sanitation Issue")
            if category not in VALID_CATEGORIES:
                category = "Public Sanitation Issue"
                
            severity = result.get("severity", "Medium")
            if severity not in VALID_SEVERITIES:
                severity = "Medium"

            confidence = float(result.get("confidence", 0.8))
            confidence = max(0.0, min(1.0, confidence))

            reasoning = str(result.get("reasoning", "AI image analysis completed."))
            visual_markers = result.get("visual_markers", [])
            if not isinstance(visual_markers, list):
                visual_markers = [str(visual_markers)]

            return {
                "is_infrastructure_issue": is_infra,
                "category": category,
                "severity": severity,
                "confidence": confidence,
                "reasoning": reasoning,
                "visual_markers": visual_markers
            }

        except json.JSONDecodeError as je:
            logger.error(f"❌ Gemini response JSON parsing failed: {str(je)}")
            raise ValueError(f"Gemini returned invalid JSON: {str(je)}")
        except Exception as e:
            logger.error(f"❌ Gemini API failure: {type(e).__name__}: {str(e)}", exc_info=True)
            raise

gemini_service = GeminiVisionService()
