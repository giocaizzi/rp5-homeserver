"""
OpenClaw Model Router Skill

Routes requests to cost-appropriate models with subscription + pay-as-you-go strategy:
- Complex tasks → Sonnet 4.6 ONLY (Anthropic subscription, NO OpenAI fallback)
- Routine tasks → Haiku 4.5 (Anthropic subscription), fallback to GPT-5 mini (OpenAI PAYG)
- Default → Haiku 4.5 (Anthropic subscription)

Protects against high OpenAI PAYG costs by NEVER routing complex tasks to OpenAI.

Based on: https://x.com/KSimback/status/2023362295166873743

To customize: Edit the self.rules patterns below to match your workflow.
"""

import logging
import re
from typing import Dict, Pattern, Tuple

# Configure logger for OpenClaw skill
logger = logging.getLogger('openclaw.skills.router')
logger.setLevel(logging.INFO)


class RouterSkill:
    """Routes queries to cost-appropriate models based on keyword patterns."""
    
    def __init__(self):
        # Pattern → (Primary Model, Fallback Model) mapping
        # Fallback is None for complex tasks (NO OpenAI PAYG for expensive tasks)
        self.rules: Dict[Pattern, Tuple[str, str | None]] = {
            # Complex tasks - Sonnet ONLY, NO OpenAI fallback (avoid PAYG costs)
            re.compile(r'\b(code|debug|script|refactor|implement|fix|optimize)\b', re.I): 
                ('anthropic/claude-sonnet-4-6', None),
            
            re.compile(r'\b(plan|strategy|brainstorm|analyze|design|architect|solve)\b', re.I): 
                ('anthropic/claude-sonnet-4-6', None),
            
            re.compile(r'\b(explain|understand|reason|think|deduce|infer)\b', re.I): 
                ('anthropic/claude-sonnet-4-6', None),
            
            # Routine tasks - Haiku primary, GPT-5 mini fallback (cheap OpenAI PAYG if needed)
            re.compile(r'\b(email|schedule|remind|calendar|appointment|meeting)\b', re.I): 
                ('anthropic/claude-haiku-4-5', 'openai/gpt-5-mini'),
            
            re.compile(r'\b(list|show|get|fetch|find|search|lookup|check)\b', re.I): 
                ('anthropic/claude-haiku-4-5', 'openai/gpt-5-mini'),
            
            re.compile(r'\b(summarize|summary|tldr|brief|quick)\b', re.I): 
                ('anthropic/claude-haiku-4-5', 'openai/gpt-5-mini'),
        }
        
        # Default fallback: Haiku primary, GPT-5 mini as safety fallback
        self.default_primary = 'anthropic/claude-haiku-4-5'
        self.default_fallback = 'openai/gpt-5-mini'
    
    def route(self, prompt: str) -> Tuple[str, str | None]:
        """
        Match prompt against patterns and return (primary_model, fallback_model).
        
        Args:
            prompt: User's message content
            
        Returns:
            Tuple of (primary_model, fallback_model). Fallback is None for complex tasks.
        """
        for pattern, models in self.rules.items():
            if pattern.search(prompt):
                return models
        
        return (self.default_primary, self.default_fallback)
    
    async def execute(self, context):
        """
        OpenClaw skill entry point.
        
        Analyzes the incoming message and overrides the model selection
        for this request, then continues the skill chain.
        
        Args:
            context: OpenClaw context object with message, session, etc.
        """
        logger.info("Router skill invoked")
        
        if hasattr(context, 'message') and hasattr(context.message, 'content'):
            prompt = context.message.content.lower()
            primary_model, fallback_model = self.route(prompt)
            
            logger.info(f"Routing decision: primary={primary_model}, fallback={fallback_model or 'NONE'}")
            
            # Override model for this session/request
            if hasattr(context, 'llm_model'):
                context.llm_model = primary_model
                logger.info(f"Model set to: {primary_model}")
            
            # Set fallback if available
            if fallback_model and hasattr(context, 'llm_fallback_model'):
                context.llm_fallback_model = fallback_model
                logger.info(f"Fallback set to: {fallback_model}")
            elif fallback_model is None:
                logger.info("Complex task detected - no PAYG fallback (cost protection)")
            
            # Log to OpenClaw's internal logging if available
            if hasattr(context, 'log'):
                context.log(f"Router: {primary_model} (fallback: {fallback_model or 'none'})")
        else:
            logger.warning("No message content found in context")
        
        # Continue to next skill in chain
        if hasattr(self, 'next') and callable(self.next):
            return await self.next(context)
