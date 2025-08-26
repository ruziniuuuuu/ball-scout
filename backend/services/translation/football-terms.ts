/**
 * 足球术语词典和翻译优化
 * 专门处理足球相关的专业术语、球员名称、球队名称等
 */

export class FootballTerms {
  private termMappings: Map<string, string> = new Map();
  private protectedTerms: string[] = [];
  private teamMappings: Map<string, string> = new Map();
  private playerMappings: Map<string, string> = new Map();
  private competitionMappings: Map<string, string> = new Map();

  constructor() {
    this.initializeTermMappings();
    this.initializeTeamMappings();
    this.initializePlayerMappings();
    this.initializeCompetitionMappings();
    this.initializeProtectedTerms();
  }

  /**
   * 初始化足球术语映射
   */
  private initializeTermMappings() {
    const terms = [
      // 基础术语
      ['football', '足球'],
      ['soccer', '足球'],
      ['goal', '进球'],
      ['assist', '助攻'],
      ['penalty', '点球'],
      ['free kick', '任意球'],
      ['corner kick', '角球'],
      ['offside', '越位'],
      ['yellow card', '黄牌'],
      ['red card', '红牌'],
      ['substitution', '换人'],
      ['half-time', '半场'],
      ['full-time', '全场'],
      ['extra time', '加时赛'],
      ['penalty shootout', '点球大战'],

      // 位置术语
      ['goalkeeper', '门将'],
      ['defender', '后卫'],
      ['midfielder', '中场'],
      ['forward', '前锋'],
      ['striker', '前锋'],
      ['winger', '边锋'],
      ['centre-back', '中后卫'],
      ['full-back', '边后卫'],
      ['defensive midfielder', '防守型中场'],
      ['attacking midfielder', '攻击型中场'],

      // 战术术语
      ['formation', '阵型'],
      ['tactic', '战术'],
      ['counter-attack', '反击'],
      ['pressing', '压迫'],
      ['possession', '控球'],
      ['cross', '传中'],
      ['through ball', '直塞'],
      ['one-touch', '一脚出球'],
      ['header', '头球'],
      ['volley', '凌空抽射'],

      // 比赛结果
      ['victory', '胜利'],
      ['defeat', '失败'],
      ['draw', '平局'],
      ['win', '获胜'],
      ['loss', '失利'],
      ['nil', '零'],
      ['clean sheet', '零封'],

      // 转会术语
      ['transfer', '转会'],
      ['signing', '签约'],
      ['contract', '合同'],
      ['loan', '租借'],
      ['release clause', '解约金条款'],
      ['agent', '经纪人'],
      ['medical', '体检'],
      ['fee', '转会费'],

      // 伤病术语
      ['injury', '伤病'],
      ['injured', '受伤'],
      ['fitness', '体能'],
      ['recovery', '康复'],
      ['surgery', '手术'],
      ['rehabilitation', '康复训练'],

      // 其他重要术语
      ['manager', '主教练'],
      ['coach', '教练'],
      ['referee', '裁判'],
      ['linesman', '边裁'],
      ['VAR', 'VAR'],
      ['stadium', '体育场'],
      ['pitch', '球场'],
      ['derby', '德比'],
      ['relegation', '降级'],
      ['promotion', '升级'],
      ['playoffs', '附加赛'],
    ];

    terms.forEach(([english, chinese]) => {
      this.termMappings.set(english.toLowerCase(), chinese);
    });
  }

  /**
   * 初始化球队名称映射
   */
  private initializeTeamMappings() {
    const teams = [
      // 英超
      ['Manchester United', '曼联'],
      ['Manchester City', '曼城'],
      ['Liverpool', '利物浦'],
      ['Arsenal', '阿森纳'],
      ['Chelsea', '切尔西'],
      ['Tottenham', '热刺'],
      ['Newcastle United', '纽卡斯尔'],
      ['West Ham United', '西汉姆联'],
      ['Brighton', '布莱顿'],
      ['Aston Villa', '阿斯顿维拉'],

      // 西甲
      ['Real Madrid', '皇家马德里'],
      ['Barcelona', '巴塞罗那'],
      ['Atletico Madrid', '马德里竞技'],
      ['Sevilla', '塞维利亚'],
      ['Valencia', '瓦伦西亚'],
      ['Villarreal', '比利亚雷亚尔'],
      ['Real Sociedad', '皇家社会'],
      ['Athletic Bilbao', '毕尔巴鄂竞技'],

      // 意甲
      ['Juventus', '尤文图斯'],
      ['Inter Milan', '国际米兰'],
      ['AC Milan', '交流米兰'],
      ['Napoli', '那不勒斯'],
      ['Roma', '罗马'],
      ['Lazio', '拉齐奥'],
      ['Atalanta', '亚特兰大'],
      ['Fiorentina', '佛罗伦萨'],

      // 德甲
      ['Bayern Munich', '拜仁慕尼黑'],
      ['Borussia Dortmund', '多特蒙德'],
      ['RB Leipzig', '莱比锡红牛'],
      ['Bayer Leverkusen', '勒沃库森'],
      ['Eintracht Frankfurt', '法兰克福'],
      ['Wolfsburg', '沃尔夫斯堡'],

      // 法甲
      ['Paris Saint-Germain', '巴黎圣日耳曼'],
      ['Marseille', '马赛'],
      ['Lyon', '里昂'],
      ['Monaco', '摩纳哥'],
      ['Nice', '尼斯'],
      ['Lille', '里尔'],

      // 其他知名球队
      ['Ajax', '阿贾克斯'],
      ['PSV', 'PSV埃因霍温'],
      ['Porto', '波尔图'],
      ['Benfica', '本菲卡'],
      ['Sporting CP', '葡萄牙体育'],
    ];

    teams.forEach(([english, chinese]) => {
      this.teamMappings.set(english, chinese);
      this.protectedTerms.push(english);
    });
  }

  /**
   * 初始化球员名称映射
   */
  private initializePlayerMappings() {
    const players = [
      // 现役巨星
      ['Lionel Messi', '梅西'],
      ['Cristiano Ronaldo', '克里斯蒂亚诺·罗纳尔多'],
      ['Kylian Mbappé', '姆巴佩'],
      ['Erling Haaland', '哈兰德'],
      ['Kevin De Bruyne', '德布劳内'],
      ['Mohamed Salah', '萨拉赫'],
      ['Karim Benzema', '本泽马'],
      ['Robert Lewandowski', '莱万多夫斯基'],
      ['Luka Modrić', '莫德里奇'],
      ['Virgil van Dijk', '范迪克'],
      ['Sadio Mané', '马内'],
      ['Harry Kane', '凯恩'],
      ['Pedri', '佩德里'],
      ['Gavi', '加维'],
      ['Jude Bellingham', '贝林厄姆'],
      ['Vinícius Jr.', '维尼修斯'],
      ['Federico Valverde', '巴尔韦德'],
      ['Jamal Musiala', '穆西亚拉'],

      // 传奇球员
      ['Pelé', '贝利'],
      ['Diego Maradona', '马拉多纳'],
      ['Johan Cruyff', '克鲁伊夫'],
      ['Franz Beckenbauer', '贝肯鲍尔'],
      ['Zinédine Zidane', '齐达内'],
      ['Ronaldinho', '罗纳尔迪尼奥'],
      ['Thierry Henry', '亨利'],
      ['Andrea Pirlo', '皮尔洛'],
      ['Francesco Totti', '托蒂'],
      ['Paolo Maldini', '马尔蒂尼'],
    ];

    players.forEach(([english, chinese]) => {
      this.playerMappings.set(english, chinese);
      this.protectedTerms.push(english);
    });
  }

  /**
   * 初始化赛事名称映射
   */
  private initializeCompetitionMappings() {
    const competitions = [
      // 欧洲赛事
      ['UEFA Champions League', '欧洲冠军联赛'],
      ['UEFA Europa League', '欧洲联赛'],
      ['UEFA Conference League', '欧洲协会联赛'],
      ['UEFA European Championship', '欧洲杯'],
      ['UEFA Nations League', '欧洲国家联赛'],

      // 世界赛事
      ['FIFA World Cup', '世界杯'],
      ['FIFA Club World Cup', '世俱杯'],
      ['Copa América', '美洲杯'],
      ['Africa Cup of Nations', '非洲杯'],
      ['Asian Cup', '亚洲杯'],

      // 联赛
      ['Premier League', '英超联赛'],
      ['La Liga', '西甲联赛'],
      ['Serie A', '意甲联赛'],
      ['Bundesliga', '德甲联赛'],
      ['Ligue 1', '法甲联赛'],
      ['Eredivisie', '荷甲联赛'],
      ['Primeira Liga', '葡超联赛'],

      // 杯赛
      ['FA Cup', '足总杯'],
      ['Copa del Rey', '国王杯'],
      ['Coppa Italia', '意大利杯'],
      ['DFB-Pokal', '德国杯'],
      ['Coupe de France', '法国杯'],
      ['EFL Cup', '联赛杯'],
      ['Community Shield', '社区盾杯'],
      ['Supercopa de España', '西班牙超级杯'],
      ['Supercoppa Italiana', '意大利超级杯'],

      // 其他重要赛事
      ['El Clásico', '国家德比'],
      ['Manchester Derby', '曼彻斯特德比'],
      ['North London Derby', '北伦敦德比'],
      ['Milan Derby', '米兰德比'],
      ['Der Klassiker', '德国国家德比'],
    ];

    competitions.forEach(([english, chinese]) => {
      this.competitionMappings.set(english, chinese);
      this.protectedTerms.push(english);
    });
  }

  /**
   * 初始化受保护术语列表
   */
  private initializeProtectedTerms() {
    // 添加所有映射中的英文术语到保护列表
    this.teamMappings.forEach((chinese, english) => {
      if (!this.protectedTerms.includes(english)) {
        this.protectedTerms.push(english);
      }
    });

    this.playerMappings.forEach((chinese, english) => {
      if (!this.protectedTerms.includes(english)) {
        this.protectedTerms.push(english);
      }
    });

    this.competitionMappings.forEach((chinese, english) => {
      if (!this.protectedTerms.includes(english)) {
        this.protectedTerms.push(english);
      }
    });
  }

  /**
   * 获取术语映射
   */
  getTermMappings(): Map<string, string> {
    return this.termMappings;
  }

  /**
   * 获取受保护术语
   */
  getProtectedTerms(): string[] {
    return this.protectedTerms;
  }

  /**
   * 获取球队映射
   */
  getTeamMappings(): Map<string, string> {
    return this.teamMappings;
  }

  /**
   * 获取球员映射
   */
  getPlayerMappings(): Map<string, string> {
    return this.playerMappings;
  }

  /**
   * 获取赛事映射
   */
  getCompetitionMappings(): Map<string, string> {
    return this.competitionMappings;
  }

  /**
   * 智能术语替换
   */
  replaceTerms(text: string): string {
    let result = text;

    // 替换球队名称（优先级最高）
    this.teamMappings.forEach((chinese, english) => {
      const regex = new RegExp(`\\b${this.escapeRegex(english)}\\b`, 'gi');
      result = result.replace(regex, chinese);
    });

    // 替换球员名称
    this.playerMappings.forEach((chinese, english) => {
      const regex = new RegExp(`\\b${this.escapeRegex(english)}\\b`, 'gi');
      result = result.replace(regex, chinese);
    });

    // 替换赛事名称
    this.competitionMappings.forEach((chinese, english) => {
      const regex = new RegExp(`\\b${this.escapeRegex(english)}\\b`, 'gi');
      result = result.replace(regex, chinese);
    });

    // 替换通用足球术语
    this.termMappings.forEach((chinese, english) => {
      const regex = new RegExp(`\\b${this.escapeRegex(english)}\\b`, 'gi');
      result = result.replace(regex, chinese);
    });

    return result;
  }

  /**
   * 转义正则表达式特殊字符
   */
  private escapeRegex(string: string): string {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 检测文本中的足球实体
   */
  detectFootballEntities(text: string): {
    teams: string[];
    players: string[];
    competitions: string[];
    terms: string[];
  } {
    const entities = {
      teams: [] as string[],
      players: [] as string[],
      competitions: [] as string[],
      terms: [] as string[],
    };

    const lowerText = text.toLowerCase();

    // 检测球队
    this.teamMappings.forEach((chinese, english) => {
      if (lowerText.includes(english.toLowerCase())) {
        entities.teams.push(english);
      }
    });

    // 检测球员
    this.playerMappings.forEach((chinese, english) => {
      if (lowerText.includes(english.toLowerCase())) {
        entities.players.push(english);
      }
    });

    // 检测赛事
    this.competitionMappings.forEach((chinese, english) => {
      if (lowerText.includes(english.toLowerCase())) {
        entities.competitions.push(english);
      }
    });

    // 检测术语
    this.termMappings.forEach((chinese, english) => {
      if (lowerText.includes(english)) {
        entities.terms.push(english);
      }
    });

    return entities;
  }

  /**
   * 生成翻译上下文提示
   */
  generateContextPrompt(text: string): string {
    const entities = this.detectFootballEntities(text);
    const contextParts: string[] = [
      '这是一篇足球新闻，请注意以下要点：',
      '1. 保持足球术语的专业性和准确性',
      '2. 球员和球队名称使用中文惯用译名',
      '3. 保持原文的语气和风格',
      '4. 确保翻译流畅自然，符合中文表达习惯',
    ];

    if (entities.teams.length > 0) {
      contextParts.push(`\n涉及的球队：${entities.teams.join(', ')}`);
    }

    if (entities.players.length > 0) {
      contextParts.push(`涉及的球员：${entities.players.join(', ')}`);
    }

    if (entities.competitions.length > 0) {
      contextParts.push(`涉及的赛事：${entities.competitions.join(', ')}`);
    }

    return contextParts.join('\n');
  }
}
