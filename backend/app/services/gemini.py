import json
import logging
import google.generativeai as genai
from app.core.config import settings

logger = logging.getLogger("aquafix.gemini")
logging.basicConfig(level=logging.INFO)

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
            # Initialize generative AI client
            genai.configure(api_key=self.api_key)
            # Use gemini-1.5-flash for rapid multimodal ingestion
            self.model = genai.GenerativeModel("gemini-1.5-flash")

    async def verify_and_categorize_incident(self, image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
        """
        Sends image binary payload to Gemini 1.5 Flash for visual verification (spam filtering)
        and auto-categorization. Returns a structured metadata dictionary.
        """
        if self.use_mock:
            # Perform elegant mock prediction based on the assumption that a tester is uploading
            # a valid image, returning structured simulated data.
            logger.info("🤖 [MOCK ENGINE] Simulating visual verification on incident image.")
            return {
                "is_infrastructure_issue": True,
                "category": "Pipeline Leak",
                "confidence": 0.98,
                "reasoning": "Mock verification succeeded. Image shows running water from a fractured pavement seam."
            }

        # Prompt specifying exact output format
        prompt = (
            "You are an expert municipal infrastructure auditor and public safety inspector.\n"
            "Analyze the uploaded image and perform two tasks:\n"
            "1. SPAM FILTERING: Verify if the image genuinely depicts a public utility, infrastructure, "
            "or public sanitation/water issue (e.g., broken water pipelines, overflowing drainage, sewage, "
            "flooded roads, sinkholes, public toilet issues).\n"
            "2. AUTO-CATEGORIZATION: If it is a valid issue, categorize it into one of these strict categories:\n"
            "   - 'Pipeline Leak'\n"
            "   - 'Drainage Blockage'\n"
            "   - 'Overflowing Sewage'\n"
            "   - 'Road Sinkhole'\n"
            "   - 'Public Sanitation Issue'\n\n"
            "You MUST respond ONLY with a valid JSON block of the following shape, with NO extra text or markdown formatting:\n"
            "{\n"
            "  \"is_infrastructure_issue\": true,\n"
            "  \"category\": \"Pipeline Leak\",\n"
            "  \"confidence\": 0.95,\n"
            "  \"reasoning\": \"Explain briefly what visual markers verify this identification.\"\n"
            "}\n"
            "If the image is not a valid infrastructure issue (e.g., a selfie, random scenery, food, or spam), "
            "set \"is_infrastructure_issue\" to false and specify the reasoning."
        )

        try:
            # Prepare image part
            image_part = {
                "mime_type": mime_type,
                "data": image_bytes
            }

            # Generate content from model with timeout and config
            response = self.model.generate_content(
                [prompt, image_part],
                generation_config=genai.types.GenerationConfig(
                    temperature=0.2,
                    top_p=0.95,
                    max_output_tokens=500
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

            # Parse and validate response structure
            result = json.loads(text_response)
            
            # Validate required fields exist
            required_fields = {"is_infrastructure_issue", "category", "confidence", "reasoning"}
            missing_fields = required_fields - set(result.keys())
            if missing_fields:
                logger.error(f"Gemini response missing required fields: {missing_fields}")
                raise ValueError(f"Invalid response structure: missing {missing_fields}")
            
            # Validate field types
            if not isinstance(result["is_infrastructure_issue"], bool):
                logger.error(f"Invalid is_infrastructure_issue type: {type(result['is_infrastructure_issue'])}")
                raise ValueError("is_infrastructure_issue must be boolean")
            
            if not isinstance(result["confidence"], (int, float)) or not (0 <= result["confidence"] <= 1):
                logger.error(f"Invalid confidence value: {result['confidence']}")
                raise ValueError("confidence must be a number between 0 and 1")
            
            # Validate category if it's an infrastructure issue
            if result["is_infrastructure_issue"]:
                valid_categories = {
                    "Pipeline Leak", "Drainage Blockage", "Overflowing Sewage",
                    "Road Sinkhole", "Public Sanitation Issue"
                }
                if result["category"] not in valid_categories:
                    logger.warning(f"Gemini returned unexpected category: {result['category']}, defaulting to 'Public Sanitation Issue'")
                    result["category"] = "Public Sanitation Issue"
            
            logger.info(f"✅ Gemini Analysis Success: is_infrastructure={result['is_infrastructure_issue']}, category={result['category']}, confidence={result['confidence']}")
            return result

        except json.JSONDecodeError as je:
            logger.error(f"❌ Gemini response JSON parsing failed: {str(je)}")
            logger.debug(f"Raw response: {text_response[:200] if text_response else 'None'}")
            raise ValueError(f"Gemini returned invalid JSON: {str(je)}")
        
        except ValueError as ve:
            logger.error(f"❌ Gemini response validation failed: {str(ve)}")
            raise
        
        except Exception as e:
            logger.error(f"❌ Gemini API critical failure: {type(e).__name__}: {str(e)}", exc_info=True)
            raise

# Instantiate singleton service instance
gemini_service = GeminiVisionService()
