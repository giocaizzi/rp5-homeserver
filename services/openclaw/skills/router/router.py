"""
OpenClaw Model Router Skill

Routes requests to appropriate models based on task complexity:
- Routine tasks (email, schedule, reminders) → Haiku 4.5 ($1/$5 per MTok)
- Complex tasks (coding, planning, analysis) → Sonnet 4.6 ($3/$15 per MTok)

Reduces API costs by 80-90% compared to using a single frontier model for everything.

Based on: https://x.com/KSimback/status/2023362295166873743

To customize: Edit the self.rules patterns below to match your workflow.
"""

import re
from typing import Dict, Pattern


class RouterSkill:
    """Routes queries to cost-appropriate models based on keyword patterns."""
    
    def __init__(self):
        # Pattern → Model mapping (order matters - first match wins)
        self.rules: Dict[Pattern, str] = {
            # Complex tasks - use Sonnet 4.6
            re.compile(r'\b(code|debug|script|refactor|implement|fix|optimize)\b', re.I): 
                'anthropic/claude-sonnet-4-6',
            
            re.compile(r'\b(plan|strategy|brainstorm|analyze|design|architect|solve)\b', re.I): 
                'anthropic/claude-sonnet-4-6',
            
            re.compile(r'\b(explain|understand|reason|think|deduce|infer)\b', re.I): 
                'anthropic/claude-sonnet-4-6',
            
            # Routine tasks - use Haiku 4.5
            re.compile(r'\b(email|schedule|remind|calendar|appointment|meeting)\b', re.I): 
                'anthropic/claude-haiku-4-5',
            
            re.compile(r'\b(list|show|get|fetch|find|search|lookup|check)\b', re.I): 
                'anthropic/claude-haiku-4-5',
            
            re.compile(r'\b(summarize|summary|tldr|brief|quick)\b', re.I): 
                'anthropic/claude-haiku-4-5',
        }
        
        # Default fallback model (cheapest)
        self.default_model = 'anthropic/claude-haiku-4-5'
    
    def route(self, prompt: str) -> str:
        """
        Match prompt against patterns and return appropriate model.
        
        Args:
            prompt: User's message content
            
        Returns:
            Model identifier string
        """
        for pattern, model in self.rules.items():
            if pattern.search(prompt):
                return model
        
        return self.default_model
    
    async def execute(self, context):
        """
        OpenClaw skill entry point.
        
        Analyzes the incoming message and overrides the model selection
        for this request, then continues the skill chain.
        
        Args:
            context: OpenClaw context object with message, session, etc.
        """
        if hasattr(context, 'message') and hasattr(context.message, 'content'):
            prompt = context.message.content.lower()
            selected_model = self.route(prompt)
            
            # Override model for this session/request
            if hasattr(context, 'llm_model'):
                context.llm_model = selected_model
            
            # Log routing decision (visible in CLI with --verbose)
            if hasattr(context, 'log'):
                context.log(f"Router: {selected_model}")
        
        # Continue to next skill in chain
        if hasattr(self, 'next') and callable(self.next):
            return await self.next(context)
