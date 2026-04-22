import { SkillDefinition } from "../../skills/index.js";

/**
 * 에이전트 세션이 들고 다니는 활성 스킬 표현 + 변형 헬퍼.
 * 세션 중에 skill 내용이 갱신(read_skill 등)될 수 있어 가변 목록을 유지한다.
 */
export type ActiveSkill = Pick<
  SkillDefinition,
  "name" | "description" | "tools" | "content" | "isApp"
>;

function cloneSkill(skill: ActiveSkill): ActiveSkill {
  return {
    name: skill.name,
    description: skill.description,
    tools: [...skill.tools],
    content: skill.content,
    isApp: skill.isApp,
  };
}

export function cloneActiveSkills(skills: ActiveSkill[]): ActiveSkill[] {
  return skills.map(cloneSkill);
}

export function mergeActiveSkill(
  activeSkills: ActiveSkill[],
  details: any,
): ActiveSkill[] {
  if (
    !details?.ok ||
    typeof details?.name !== "string" ||
    typeof details?.content !== "string"
  ) {
    return cloneActiveSkills(activeSkills);
  }

  const nextSkill: ActiveSkill = {
    name: details.name,
    description:
      typeof details.description === "string" ? details.description : "",
    tools: Array.isArray(details.tools)
      ? details.tools.filter(
          (tool: unknown): tool is string => typeof tool === "string",
        )
      : [],
    content: details.content,
    isApp: !!details.isApp,
  };

  const remaining = activeSkills.filter(
    (skill) => skill.name !== nextSkill.name,
  );
  return [...cloneActiveSkills(remaining), nextSkill];
}
