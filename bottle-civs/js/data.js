// Static content: the first ten races of the bottle world (+ two sealed jars for later).
(function (g) {
  g.BC = g.BC || {};

  const RES = ['food', 'wood', 'ore', 'goods', 'lore', 'gold'];

  // mult: production multipliers per resource (+ might for soldiering)
  // traits: aggression / greed / openness (0..1), fertility (births per pair per day), lifespan (days)
  const RACES = [
    { id: 'elf', name: 'Elves', jar: 'Glimmerwood', sprite: 'elf_f', color: '#7ad98a',
      skill: 'Herbalism', blurb: 'Forest-wardens whose gardens feed a lot of mouths and whose libraries run deep.',
      mult: { food: 1.25, wood: 1.15, ore: 0.7, goods: 1.0, lore: 1.3, gold: 1.0, might: 0.9 },
      traits: { aggression: 0.2, greed: 0.3, openness: 0.7, fertility: 0.10, lifespan: 60 },
      like: ['human', 'wizard'], dislike: ['orc', 'goblin', 'dwarf'] },
    { id: 'dwarf', name: 'Dwarves', jar: 'Deepforge', sprite: 'dwarf_m', color: '#d9a35a',
      skill: 'Deep Mining', blurb: 'Ore and goods in absurd quantities. Hoard gold, hold grudges.',
      mult: { food: 0.85, wood: 0.9, ore: 1.7, goods: 1.35, lore: 0.9, gold: 1.1, might: 1.1 },
      traits: { aggression: 0.4, greed: 0.8, openness: 0.35, fertility: 0.10, lifespan: 45 },
      like: ['human', 'ogre'], dislike: ['elf', 'goblin'] },
    { id: 'human', name: 'Humans', jar: 'Crownmere', sprite: 'knight_m', color: '#6aa8ff',
      skill: 'Trade & Diplomacy', blurb: 'Jack-of-all-trades. Their merchants make better deals and friends everywhere.',
      mult: { food: 1.0, wood: 1.0, ore: 1.0, goods: 1.0, lore: 1.0, gold: 1.4, might: 1.0 },
      traits: { aggression: 0.35, greed: 0.5, openness: 0.85, fertility: 0.14, lifespan: 30 },
      like: ['elf', 'dwarf', 'wizard'], dislike: ['orc', 'imp'], tradeBonus: 1.25, charm: 1.5 },
    { id: 'lizard', name: 'Lizardfolk', jar: 'Mirefen', sprite: 'lizard_m', color: '#9acd32',
      skill: 'Swamp Farming', blurb: 'Clutch-hatchers. Fast growing, fast fed, and surprisingly sociable.',
      mult: { food: 1.55, wood: 1.1, ore: 0.8, goods: 0.8, lore: 0.8, gold: 0.9, might: 0.95 },
      traits: { aggression: 0.3, greed: 0.3, openness: 0.55, fertility: 0.22, lifespan: 26 },
      like: ['ogre', 'goblin'], dislike: ['elf'] },
    { id: 'orc', name: 'Orcs', jar: 'Skullgrit', sprite: 'orc_warrior', color: '#e0533d',
      skill: 'Warcraft', blurb: 'Born to the shield wall. Raiders first, farmers when they must be.',
      mult: { food: 0.9, wood: 1.0, ore: 1.0, goods: 0.9, lore: 0.6, gold: 0.8, might: 1.5 },
      traits: { aggression: 0.9, greed: 0.5, openness: 0.3, fertility: 0.17, lifespan: 28 },
      like: ['ogre', 'goblin'], dislike: ['elf', 'human', 'dwarf'], soldierShare: 0.4 },
    { id: 'goblin', name: 'Goblins', jar: 'Rustwick', sprite: 'goblin', color: '#b4d94a',
      skill: 'Tinkering', blurb: 'Scrap-engineers. They build, scavenge and steal in roughly that order.',
      mult: { food: 0.9, wood: 1.0, ore: 1.0, goods: 1.5, lore: 1.0, gold: 1.0, might: 0.8 },
      traits: { aggression: 0.55, greed: 0.9, openness: 0.5, fertility: 0.24, lifespan: 20 },
      like: ['orc', 'imp', 'lizard'], dislike: ['elf', 'dwarf'], plunder: 1.4 },
    { id: 'skeleton', name: 'Skeletons', jar: 'Hollowbone', sprite: 'skelet', color: '#d8d8c8',
      skill: 'Undying', blurb: 'Barely eat, never age, cannot breed. They raise the fallen of every battle they win.',
      mult: { food: 0.4, wood: 1.0, ore: 1.2, goods: 1.0, lore: 1.0, gold: 0.7, might: 1.1 },
      traits: { aggression: 0.65, greed: 0.2, openness: 0.2, fertility: 0.0, lifespan: 400 },
      like: ['imp'], dislike: ['elf', 'human', 'lizard'], eats: 0.15, raiseDead: true },
    { id: 'ogre', name: 'Ogres', jar: 'Mugdrum', sprite: 'ogre', color: '#c98f6b',
      skill: 'Brewing & Brawn', blurb: 'Slow, huge and cheerful. Their ale turns surplus grain into gold.',
      mult: { food: 1.0, wood: 1.3, ore: 1.1, goods: 0.8, lore: 0.5, gold: 1.2, might: 1.3 },
      traits: { aggression: 0.5, greed: 0.4, openness: 0.5, fertility: 0.12, lifespan: 36 },
      like: ['orc', 'lizard', 'dwarf'], dislike: ['wizard'], hp: 2.0, brew: true },
    { id: 'imp', name: 'Imps', jar: 'Cinderhex', sprite: 'imp', color: '#c14aff',
      skill: 'Trickery', blurb: 'Tiny schemers. They steal gold and frame neighbours for crimes.',
      mult: { food: 0.9, wood: 0.9, ore: 0.9, goods: 1.1, lore: 1.1, gold: 1.3, might: 0.7 },
      traits: { aggression: 0.35, greed: 0.85, openness: 0.6, fertility: 0.20, lifespan: 24 },
      like: ['goblin', 'skeleton'], dislike: ['wizard', 'human'], spy: true, hp: 0.7 },
    { id: 'wizard', name: 'Wizards', jar: 'Aethervault', sprite: 'wizzard_m', color: '#5ad1ff',
      skill: 'Arcane Lore', blurb: 'Their towers turn lore into everything else. Frail, but terrifyingly clever.',
      mult: { food: 0.9, wood: 0.8, ore: 0.8, goods: 1.15, lore: 1.9, gold: 1.0, might: 0.8 },
      traits: { aggression: 0.25, greed: 0.45, openness: 0.55, fertility: 0.08, lifespan: 70 },
      like: ['elf', 'human'], dislike: ['imp', 'ogre'], techBonus: 1.5, hp: 0.8 },
  ];

  // Two jars exist but are still sealed - future content.
  const SEALED = [
    { id: 'chort', name: 'Chorts', jar: 'Sealed Jar XI', sprite: 'chort', color: '#e8613a' },
    { id: 'angel', name: 'Angels', jar: 'Sealed Jar XII', sprite: 'angel', color: '#f6e27a' },
  ];

  // Jar slots: 4 columns x 3 rows. Slots 0..9 are live civs, 10..11 sealed.
  const GRID = { cols: 4, rows: 3 };

  g.BC.DATA = { RES, RACES, SEALED, GRID };
})(typeof window !== 'undefined' ? window : globalThis);
