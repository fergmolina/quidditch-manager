#!/usr/bin/env python3
"""Fixed, hand-designed filler clubs (the same in every save): alliterative names in the style of
"Quidditch Through the Ages" (Toyohashi Tengu, Patonga Proudsticks, Braga Broomfleet), in the region's
language and featuring local folklore creatures where it fits. All are [FILLER]: the books do not name them.
Writes data/packs/1993-94/clubs/club_<id>.json and adds the clubs to their leagues (filler_clubs = 0).
Usage: python3 tools/author_clubs.py"""
import json, os, re, unicodedata
from typing import NamedTuple

PACK = "data/packs/1993-94"
COUNTRY = {"nga": "Nigeria", "sen": "Senegal", "egy": "Egipto", "mwi": "Malaui", "bfa": "Burkina Faso", "civ": "Costa de Marfil",
           "tcd": "Chad", "per": "Perú", "chl": "Chile", "bol": "Bolivia", "ecu": "Ecuador", "col": "Colombia", "arg": "Argentina",
           "ury": "Uruguay", "pry": "Paraguay", "bra": "Brasil", "can": "Canadá", "bul": "Bulgaria", "pol": "Polonia", "ltu": "Lituania",
           "rou": "Rumania", "mda": "Moldavia", "tra": "Transilvania", "fra": "Francia", "deu": "Alemania", "aut": "Austria",
           "che": "Suiza", "lie": "Liechtenstein", "prt": "Portugal", "esp": "España", "jpn": "Japón", "mex": "México", "hti": "Haití",
           "jam": "Jamaica", "cub": "Cuba", "nor": "Noruega", "swe": "Suecia", "dnk": "Dinamarca", "fin": "Finlandia", "isl": "Islandia",
           "aus": "Australia", "nzl": "Nueva Zelanda", "fji": "Fiyi", "usa": "Estados Unidos", "ind": "India",
           "ita": "Italia", "chn": "China", "kor": "Corea del Sur", "nld": "Países Bajos", "fla": "Flandes", "rus": "Rusia",
           "cze": "Chequia", "svk": "Eslovaquia", "hun": "Hungría", "tha": "Tailandia"}


class Club(NamedTuple):
    league: str
    name: str
    short_name: str
    city: str
    country: str
    founded: int
    primary: str
    secondary: str
    emblem_key: str
    emblem_desc: str
    style: str
    titles: int
    elite: bool


CLUBS = [
    Club("africa", "Lagos Lightningbolts", "Lightningbolts", "Lagos", "nga", 1891, "#1B5E20", "#FDD835", "thunder", "a forked yellow lightning bolt", "attacking", 9, True),
    Club("africa", "Kano Kingfishers", "Kingfishers", "Kano", "nga", 1904, "#0D47A1", "#FFB300", "finch", "a diving kingfisher", "balanced", 3, False),
    Club("africa", "Dakar Dune-Dancers", "Dune-Dancers", "Dakar", "sen", 1912, "#E65100", "#FFF3E0", "sunray", "a dancer swirling over sand dunes under the sun", "flamboyant", 6, True),
    Club("africa", "Cairo Crocodiles", "Crocodiles", "El Cairo", "egy", 1878, "#33691E", "#D4AF37", "charm", "a crocodile wearing a golden crown", "clever", 11, True),
    Club("africa", "Blantyre Baobabs", "Baobabs", "Blantyre", "mwi", 1930, "#33691E", "#A1887F", "tree", "a baobab tree", "resilient", 1, False),
    Club("africa", "Ouagadougou Owls", "Owls", "Uagadugú", "bfa", 1926, "#6D4C41", "#FFCC80", "harrier_hawk", "a horned owl", "defensive", 2, False),
    Club("africa", "Abidjan Antelopes", "Antelopes", "Abiyán", "civ", 1919, "#F57C00", "#2E7D32", "", "a leaping antelope", "speed", 4, False),
    Club("africa", "N'Djamena Nightjars", "Nightjars", "Yamena", "tcd", 1941, "#1A237E", "#B0BEC5", "kite_bird", "a nightjar in flight under a crescent moon", "defensive", 0, False),
    Club("andes", "Cusco Cóndores", "Cóndores", "Cusco", "per", 1884, "#8D1B1B", "#F4D03F", "vulture", "a soaring Andean condor", "dominant", 10, True),
    Club("andes", "Santiago Saetas", "Saetas", "Santiago", "chl", 1898, "#0D47A1", "#E53935", "star", "two crossed arrows over a star", "speed", 7, True),
    Club("andes", "Valparaíso Vientos", "Vientos", "Valparaíso", "chl", 1907, "#00838F", "#FFFFFF", "storm", "curling sea winds", "flair", 3, False),
    Club("andes", "La Paz Llamas", "Llamas", "La Paz", "bol", 1911, "#C62828", "#FBC02D", "meteor", "a llama wreathed in flames", "fierce", 4, False),
    Club("andes", "Quito Quetzales", "Quetzales", "Quito", "ecu", 1922, "#2E7D32", "#E53935", "macaw", "a resplendent quetzal", "attacking", 2, False),
    Club("andes", "Guayaquil Guacamayos", "Guacamayos", "Guayaquil", "ecu", 1925, "#FBC02D", "#1565C0", "macaw", "a blue-and-gold macaw", "showmanship", 1, False),
    Club("andes", "Bogotá Brujas", "Brujas", "Bogotá", "col", 1903, "#4A148C", "#9CCC65", "charm", "a witch on a broom against the moon", "aggressive", 5, True),
    Club("andes", "Medellín Mariposas", "Mariposas", "Medellín", "col", 1936, "#E91E63", "#212121", "finch", "a giant swallowtail butterfly", "flamboyant", 0, False),
    Club("argentina", "Buenos Aires Búhos", "Búhos", "Buenos Aires", "arg", 1872, "#0D47A1", "#FFFFFF", "harrier_hawk", "a barn owl", "clever", 12, True),
    Club("argentina", "Rosario Relámpagos", "Relámpagos", "Rosario", "arg", 1889, "#B71C1C", "#FFFFFF", "thunder", "a red lightning bolt", "attacking", 7, True),
    Club("argentina", "Córdoba Cometas", "Cometas", "Córdoba", "arg", 1901, "#283593", "#FFD54F", "meteor", "a comet with a long tail", "speed", 5, False),
    Club("argentina", "Mendoza Montañeses", "Montañeses", "Mendoza", "arg", 1913, "#6D4C41", "#BDBDBD", "giant", "a snow-capped Andean peak", "stamina", 2, False),
    Club("argentina", "La Plata Lobizones", "Lobizones", "La Plata", "arg", 1895, "#37474F", "#FFB300", "warrior", "a howling lobizón under the full moon", "fierce", 3, False),
    Club("argentina", "Bahía Blanca Ballenas", "Ballenas", "Bahía Blanca", "arg", 1920, "#01579B", "#E0E0E0", "", "a breaching whale", "resilient", 1, False),
    Club("argentina", "Tucumán Tucanes", "Tucanes", "San Miguel de Tucumán", "arg", 1924, "#1B5E20", "#FF9800", "macaw", "a toucan", "flair", 1, False),
    Club("argentina", "Mar del Plata Mareas", "Mareas", "Mar del Plata", "arg", 1888, "#0277BD", "#FFFFFF", "storm", "rolling Atlantic tides with a sea lion", "balanced", 6, True),
    Club("argentina", "Posadas Pomberos", "Pomberos", "Posadas", "arg", 1916, "#2E7D32", "#FFB300", "goblin", "the Pombero, a small hairy forest trickster with a wide straw hat among jungle leaves", "clever", 2, False),
    Club("brazil", "Rio Redemoinhos", "Redemoinhos", "Río de Janeiro", "bra", 1868, "#1B5E20", "#FFEB3B", "storm", "a green-and-gold whirlwind", "flamboyant", 14, True),
    Club("brazil", "São Paulo Sacis", "Sacis", "São Paulo", "bra", 1874, "#B71C1C", "#212121", "warrior", "a one-legged Saci with a red cap riding a whirlwind", "showmanship", 11, True),
    Club("brazil", "Salvador Sabiás", "Sabiás", "Salvador", "bra", 1897, "#F57F17", "#3E2723", "finch", "a singing sabiá thrush", "flair", 4, False),
    Club("brazil", "Belo Horizonte Boitatás", "Boitatás", "Belo Horizonte", "bra", 1902, "#E65100", "#212121", "charm", "a fiery serpent of light", "aggressive", 6, True),
    Club("brazil", "Porto Alegre Pampeiros", "Pampeiros", "Porto Alegre", "bra", 1906, "#0D47A1", "#FFFFFF", "storm", "a galloping horse in the pampas wind", "resilient", 3, False),
    Club("brazil", "Manaus Mapinguaris", "Mapinguaris", "Manaos", "bra", 1915, "#1B5E20", "#795548", "giant", "a towering Mapinguari of the Amazon", "physical", 2, False),
    Club("brazil", "Recife Raposas", "Raposas", "Recife", "bra", 1918, "#FF7043", "#FFFFFF", "", "a running fox", "clever", 1, False),
    Club("brazil", "Fortaleza Fogueteiros", "Fogueteiros", "Fortaleza", "bra", 1927, "#FBC02D", "#C62828", "meteor", "a rising firework rocket", "speed", 1, False),
    Club("brazil", "Curitiba Curupiras", "Curupiras", "Curitiba", "bra", 1921, "#33691E", "#FF5722", "tree", "a Curupira with backward feet beside an araucaria pine", "balanced", 2, False),
    Club("canada", "Trois-Rivières Tonnerres", "Tonnerres", "Trois-Rivières", "can", 1890, "#283593", "#FFFFFF", "thunder", "a thunderbird over a river", "attacking", 4, False),
    Club("canada", "Vancouver Voyageurs", "Voyageurs", "Vancouver", "can", 1899, "#00695C", "#FFFFFF", "broom_fleet", "a canoe paddle crossed with a broom", "stamina", 3, False),
    Club("canada", "Halifax Hurricanes", "Hurricanes", "Halifax", "can", 1905, "#37474F", "#4FC3F7", "storm", "a spiralling hurricane", "physical", 2, False),
    Club("canada", "Calgary Coyotes", "Coyotes", "Calgary", "can", 1923, "#C62828", "#FFCA28", "", "a howling coyote", "aggressive", 1, False),
    Club("canada", "Yellowknife Yetis", "Yetis", "Yellowknife", "can", 1938, "#ECEFF1", "#1565C0", "giant", "a white yeti in the snow", "resilient", 0, False),
    Club("eastern_europe", "Sofia Samodivi", "Samodivi", "Sofía", "bul", 1887, "#2E7D32", "#FFFFFF", "charm", "a dancing samodiva with flowing hair", "flair", 8, True),
    Club("eastern_europe", "Kraków Kruki", "Kruki", "Cracovia", "pol", 1876, "#212121", "#D32F2F", "vulture", "a black raven", "clever", 10, True),
    Club("eastern_europe", "Wrocław Wilki", "Wilki", "Breslavia", "pol", 1902, "#455A64", "#FFFFFF", "", "a grey wolf head", "aggressive", 4, False),
    Club("eastern_europe", "Vilnius Vytis", "Vytis", "Vilna", "ltu", 1893, "#B71C1C", "#FFFFFF", "warrior", "a knight on horseback with a raised sword", "experienced", 5, False),
    Club("eastern_europe", "Kaunas Kometos", "Kometos", "Kaunas", "ltu", 1921, "#1A237E", "#FFD600", "meteor", "a comet", "speed", 2, False),
    Club("eastern_europe", "Brașov Balauri", "Balauri", "Brașov", "tra", 1866, "#8E0000", "#212121", "charm", "a three-headed balaur dragon", "fierce", 6, True),
    Club("eastern_europe", "București Bufnițe", "Bufnițe", "Bucarest", "rou", 1910, "#FBC02D", "#1565C0", "harrier_hawk", "an eagle owl", "defensive", 1, False),
    Club("eastern_europe", "Chișinău Cocostârci", "Cocostârci", "Chisináu", "mda", 1932, "#FFFFFF", "#C62828", "kite_bird", "a white stork", "balanced", 0, False),
    Club("france", "Paris Phénix", "Phénix", "París", "fra", 1861, "#0D47A1", "#E53935", "meteor", "a phoenix rising from flames", "flamboyant", 12, True),
    Club("france", "Marseille Mistrals", "Mistrals", "Marsella", "fra", 1879, "#00ACC1", "#FFFFFF", "storm", "the Mistral wind blowing over waves", "attacking", 8, True),
    Club("france", "Lyon Lutins", "Lutins", "Lyon", "fra", 1890, "#C62828", "#FFFFFF", "goblin", "a grinning lutin imp", "clever", 4, False),
    Club("france", "Bordeaux Busards", "Busards", "Burdeos", "fra", 1896, "#6A1B9A", "#FFFFFF", "harrier_hawk", "a hen harrier", "balanced", 3, False),
    Club("france", "Toulouse Tarasques", "Tarasques", "Toulouse", "fra", 1904, "#2E7D32", "#FFC107", "giant", "the Tarasque, a turtle-shelled dragon", "physical", 2, False),
    Club("france", "Lille Licornes", "Licornes", "Lille", "fra", 1911, "#F5F5F5", "#C62828", "star", "a rearing unicorn", "showmanship", 2, False),
    Club("france", "Nantes Narvals", "Narvals", "Nantes", "fra", 1920, "#1A237E", "#B3E5FC", "", "a narwhal", "resilient", 1, False),
    Club("france", "Strasbourg Sylphes", "Sylphes", "Estrasburgo", "fra", 1928, "#81D4FA", "#1A237E", "storm", "a winged sylph", "speed", 1, False),
    Club("germany", "Berlin Blitze", "Blitze", "Berlín", "deu", 1870, "#212121", "#FFD600", "thunder", "a lightning bolt", "attacking", 11, True),
    Club("germany", "München Mondkälber", "Mondkälber", "Múnich", "deu", 1884, "#0D47A1", "#FFFFFF", "", "a mooncalf dancing under the full moon", "flair", 7, True),
    Club("germany", "Hamburg Hippogreife", "Hippogreife", "Hamburgo", "deu", 1891, "#1565C0", "#ECEFF1", "harrier_hawk", "a hippogriff", "balanced", 5, False),
    Club("germany", "Köln Kobolde", "Kobolde", "Colonia", "deu", 1899, "#C62828", "#FFFFFF", "goblin", "a kobold with a lantern", "clever", 3, False),
    Club("germany", "Wien Windhunde", "Windhunde", "Viena", "aut", 1877, "#B71C1C", "#FFFFFF", "", "a running greyhound", "speed", 6, True),
    Club("germany", "Salzburg Salamander", "Salamander", "Salzburgo", "aut", 1909, "#F9A825", "#212121", "charm", "a salamander in flames", "aggressive", 2, False),
    Club("germany", "Zürich Zentauren", "Zentauren", "Zúrich", "che", 1888, "#D32F2F", "#FFFFFF", "warrior", "a centaur archer", "experienced", 4, False),
    Club("germany", "Vaduz Vipern", "Vipern", "Vaduz", "lie", 1931, "#1B5E20", "#FFEB3B", "", "a coiled viper", "defensive", 0, False),
    Club("iberia_lux", "Madrid Mantícoras", "Mantícoras", "Madrid", "esp", 1869, "#FFFFFF", "#283593", "giant", "a manticore", "dominant", 13, True),
    Club("iberia_lux", "Barcelona Basiliscos", "Basiliscos", "Barcelona", "esp", 1873, "#A50044", "#004D98", "charm", "a crowned basilisk", "attacking", 11, True),
    Club("iberia_lux", "Sevilla Sirenas", "Sirenas", "Sevilla", "esp", 1890, "#D32F2F", "#FFFFFF", "", "a mermaid", "flair", 5, False),
    Club("iberia_lux", "Valencia Vencejos", "Vencejos", "Valencia", "esp", 1902, "#FF6F00", "#212121", "kite_bird", "a swift bird", "speed", 3, False),
    Club("iberia_lux", "Bilbao Basajaunak", "Basajaunak", "Bilbao", "esp", 1898, "#C62828", "#FFFFFF", "giant", "Basajaun, the hairy forest giant", "physical", 4, False),
    Club("iberia_lux", "Lisboa Lobisomens", "Lobisomens", "Lisboa", "prt", 1871, "#1B5E20", "#FFFFFF", "", "a werewolf howling at the moon", "fierce", 7, True),
    Club("iberia_lux", "Porto Pégasos", "Pégasos", "Oporto", "prt", 1886, "#0D47A1", "#FFFFFF", "", "a winged horse", "balanced", 6, False),
    Club("japan", "Tokyo Tatsu", "Tatsu", "Tokio", "jpn", 1882, "#B71C1C", "#FFD700", "charm", "a coiled red dragon", "dominant", 8, True),
    Club("japan", "Osaka Oni", "Oni", "Osaka", "jpn", 1890, "#212121", "#E53935", "goblin", "a horned oni mask", "fierce", 6, True),
    Club("japan", "Kyoto Kitsune", "Kitsune", "Kioto", "jpn", 1879, "#FF7043", "#FFFFFF", "", "a nine-tailed fox", "clever", 5, False),
    Club("japan", "Nagoya Namazu", "Namazu", "Nagoya", "jpn", 1908, "#37474F", "#4FC3F7", "", "a giant catfish", "physical", 2, False),
    Club("japan", "Sapporo Sagi", "Sagi", "Sapporo", "jpn", 1913, "#ECEFF1", "#1A237E", "kite_bird", "a white heron", "balanced", 3, False),
    Club("japan", "Kobe Kappa", "Kappa", "Kobe", "jpn", 1917, "#00897B", "#FFEB3B", "goblin", "a kappa with a water dish on its head", "resilient", 2, False),
    Club("japan", "Hiroshima Hōō", "Hōō", "Hiroshima", "jpn", 1922, "#FFC107", "#B71C1C", "", "a Japanese phoenix", "flair", 1, False),
    Club("japan", "Fukuoka Fūjin", "Fūjin", "Fukuoka", "jpn", 1926, "#1565C0", "#FFFFFF", "storm", "the wind god Fujin with his bag of winds", "attacking", 1, False),
    Club("mexico_caribbean", "Monterrey Monarcas", "Monarcas", "Monterrey", "mex", 1903, "#FF6F00", "#212121", "finch", "a monarch butterfly", "flair", 6, True),
    Club("mexico_caribbean", "Toluca Tlaloques", "Tlaloques", "Toluca", "mex", 1911, "#0D47A1", "#FFEB3B", "storm", "a rain spirit pouring a jar of rain", "resilient", 4, False),
    Club("mexico_caribbean", "Oaxaca Ocelotes", "Ocelotes", "Oaxaca", "mex", 1919, "#F9A825", "#3E2723", "", "an ocelot", "speed", 3, False),
    Club("mexico_caribbean", "Veracruz Víboras", "Víboras", "Veracruz", "mex", 1924, "#1B5E20", "#FFFFFF", "", "a viper", "aggressive", 2, False),
    Club("mexico_caribbean", "Cap-Haïtien Caïmans", "Caïmans", "Cabo Haitiano", "hti", 1929, "#C62828", "#1565C0", "", "a caiman", "physical", 1, False),
    Club("mexico_caribbean", "Kingston Krakens", "Krakens", "Kingston", "jam", 1915, "#2E7D32", "#FDD835", "", "a kraken rising from the sea", "fierce", 3, False),
    Club("mexico_caribbean", "La Habana Huracanes", "Huracanes", "La Habana", "cub", 1897, "#0D47A1", "#E53935", "storm", "a hurricane", "attacking", 5, True),
    Club("nordic", "Oslo Ormer", "Ormer", "Oslo", "nor", 1881, "#B71C1C", "#FFFFFF", "charm", "a coiled sea serpent", "attacking", 8, True),
    Club("nordic", "Bergen Bjørner", "Bjørner", "Bergen", "nor", 1894, "#1565C0", "#FFFFFF", "", "a bear", "physical", 5, False),
    Club("nordic", "Stockholm Stormar", "Stormar", "Estocolmo", "swe", 1876, "#0D47A1", "#FFEB3B", "storm", "a storm over the sea", "attacking", 9, True),
    Club("nordic", "Göteborg Gripar", "Gripar", "Gotemburgo", "swe", 1899, "#1A237E", "#B0BEC5", "harrier_hawk", "a griffin", "balanced", 4, False),
    Club("nordic", "København Krager", "Krager", "Copenhague", "dnk", 1888, "#212121", "#E53935", "vulture", "a hooded crow", "clever", 6, True),
    Club("nordic", "Helsinki Haukat", "Haukat", "Helsinki", "fin", 1906, "#FFFFFF", "#0D47A1", "harrier_hawk", "a hawk", "speed", 3, False),
    Club("nordic", "Tampere Tontut", "Tontut", "Tampere", "fin", 1923, "#C62828", "#FFFFFF", "goblin", "a tonttu gnome with a red cap", "flair", 1, False),
    Club("nordic", "Reykjavík Risar", "Risar", "Reikiavik", "isl", 1930, "#1565C0", "#ECEFF1", "giant", "a frost giant", "physical", 1, False),
    Club("oceania", "Sydney Sundowners", "Sundowners", "Sídney", "aus", 1877, "#FF6F00", "#0D47A1", "sunray", "the sun setting over a harbour", "flair", 6, True),
    Club("oceania", "Perth Platypuses", "Platypuses", "Perth", "aus", 1903, "#00695C", "#FFCC80", "", "a platypus", "clever", 3, False),
    Club("oceania", "Brisbane Bunyips", "Bunyips", "Brisbane", "aus", 1896, "#4E342E", "#8BC34A", "giant", "a bunyip rising from a billabong", "physical", 4, False),
    Club("oceania", "Melbourne Mopokes", "Mopokes", "Melbourne", "aus", 1884, "#212121", "#FFD54F", "harrier_hawk", "a boobook owl", "defensive", 5, False),
    Club("oceania", "Auckland Albatrosses", "Albatrosses", "Auckland", "nzl", 1890, "#212121", "#ECEFF1", "kite_bird", "an albatross", "stamina", 4, False),
    Club("oceania", "Suva Sharks", "Sharks", "Suva", "fji", 1931, "#01579B", "#4DD0E1", "", "a shark", "aggressive", 1, False),
    Club("usa", "Boston Banshees", "Banshees", "Boston", "usa", 1875, "#2E7D32", "#FFFFFF", "charm", "a wailing banshee", "fierce", 7, True),
    Club("usa", "Chicago Cyclones", "Cyclones", "Chicago", "usa", 1889, "#C62828", "#FFFFFF", "storm", "a tornado funnel", "attacking", 6, True),
    Club("usa", "New Orleans Nightshades", "Nightshades", "Nueva Orleans", "usa", 1883, "#4A148C", "#FFC107", "charm", "a nightshade flower", "clever", 4, False),
    Club("usa", "Salem Seekers", "Seekers", "Salem", "usa", 1869, "#212121", "#FF6F00", "stick", "a broom crossed with a witch hat", "balanced", 5, False),
    Club("usa", "Denver Dustdevils", "Dustdevils", "Denver", "usa", 1911, "#F57C00", "#3E2723", "storm", "a whirling dust devil", "speed", 2, False),
    Club("usa", "Seattle Sasquatches", "Sasquatches", "Seattle", "usa", 1907, "#1B5E20", "#795548", "giant", "a sasquatch in a pine forest", "physical", 3, False),
    Club("usa", "Philadelphia Phantoms", "Phantoms", "Filadelfia", "usa", 1878, "#ECEFF1", "#283593", "charm", "a ghostly phantom", "defensive", 1, False),
    Club("usa", "Savannah Swamp-Skimmers", "Swamp-Skimmers", "Savannah", "usa", 1926, "#33691E", "#FFEB3B", "kite_bird", "a heron skimming a swamp", "flair", 1, False),
    Club("usa", "New York Nifflers", "Nifflers", "Nueva York", "usa", 1872, "#1A237E", "#D4AF37", "", "a niffler clutching gold coins", "clever", 8, True),
    Club("usa", "Los Angeles Luminaries", "Luminaries", "Los Ángeles", "usa", 1912, "#4A148C", "#FFC107", "star", "a shining star over palm trees", "showmanship", 5, True),
    Club("usa", "San Francisco Sea-Serpents", "Sea-Serpents", "San Francisco", "usa", 1890, "#C62828", "#FFD54F", "charm", "a sea serpent coiled around the red tower of a suspension bridge in the fog", "flair", 4, False),
    Club("usa", "Miami Manatees", "Manatees", "Miami", "usa", 1925, "#00ACC1", "#FF7043", "", "a manatee swimming among mangroves", "resilient", 2, False),
    Club("india", "Bombay Bulbuls", "Bulbuls", "Bombay", "ind", 1894, "#0D47A1", "#FFC107", "finch", "a red-whiskered bulbul", "flair", 7, True),
    Club("india", "Delhi Dholes", "Dholes", "Delhi", "ind", 1901, "#C62828", "#FFFFFF", "", "a dhole wild dog", "aggressive", 6, True),
    Club("india", "Calcutta Cobras", "Cobras", "Calcuta", "ind", 1888, "#212121", "#FDD835", "charm", "a spectacled cobra", "clever", 5, False),
    Club("india", "Madras Mongooses", "Mongooses", "Madrás", "ind", 1906, "#795548", "#FFE082", "", "a mongoose", "speed", 3, False),
    Club("india", "Bangalore Banyans", "Banyans", "Bangalore", "ind", 1912, "#33691E", "#FFB300", "tree", "a banyan tree", "resilient", 2, False),
    Club("india", "Hyderabad Hornbills", "Hornbills", "Hyderabad", "ind", 1909, "#212121", "#FF6F00", "macaw", "a great hornbill", "balanced", 4, False),
    Club("india", "Jaipur Jugnus", "Jugnus", "Jaipur", "ind", 1924, "#E91E63", "#FFEB3B", "star", "a swarm of fireflies", "showmanship", 1, False),
    Club("india", "Pune Peacocks", "Peacocks", "Pune", "ind", 1928, "#00695C", "#1565C0", "finch", "a peacock with fanned tail", "flair", 1, False),
    Club("italy", "Roma Ruggenti", "Ruggenti", "Roma", "ita", 1871, "#8E1B1B", "#F4B400", "", "the Capitoline she-wolf roaring", "aggressive", 9, True),
    Club("italy", "Milano Mangiafuoco", "Mangiafuoco", "Milán", "ita", 1883, "#212121", "#E53935", "meteor", "a fire-breather blowing a great plume of flame", "showmanship", 8, True),
    Club("italy", "Napoli Nottole", "Nottole", "Nápoles", "ita", 1890, "#1E88E5", "#FFFFFF", "", "a noctule bat over a smoking volcano", "flair", 6, True),
    Club("italy", "Benevento Befane", "Befane", "Benevento", "ita", 1866, "#4A148C", "#FFB300", "stick", "the Befana, an old witch flying on her broomstick under the stars", "clever", 7, True),
    Club("italy", "Torino Tori", "Tori", "Turín", "ita", 1898, "#7B1F1F", "#FFFFFF", "", "a rampant bull", "resilient", 4, False),
    Club("italy", "Venezia Viverne", "Viverne", "Venecia", "ita", 1902, "#00695C", "#D4AF37", "charm", "a winged wyvern rising from lagoon waves", "balanced", 3, False),
    Club("italy", "Firenze Falchi", "Falchi", "Florencia", "ita", 1910, "#6A1B9A", "#FFFFFF", "harrier_hawk", "a falcon holding a lily flower", "flair", 2, False),
    Club("italy", "Messina Morgane", "Morgane", "Mesina", "ita", 1921, "#0277BD", "#FFD54F", "storm", "the Fata Morgana, a fairy conjuring a mirage castle over the sea", "clever", 1, False),
    Club("east_asia", "Beijing Baihu", "Baihu", "Pekín", "chn", 1880, "#C62828", "#FFFFFF", "", "a white tiger", "aggressive", 8, True),
    Club("east_asia", "Shanghai Shenlong", "Shenlong", "Shanghái", "chn", 1895, "#0D47A1", "#FFC107", "charm", "a coiled spirit dragon among clouds", "flair", 7, True),
    Club("east_asia", "Chengdu Chang'e", "Chang'e", "Chengdu", "chn", 1912, "#283593", "#ECEFF1", "star", "the moon goddess Chang'e flying to the moon with a jade rabbit", "clever", 3, False),
    Club("east_asia", "Xi'an Xiezhi", "Xiezhi", "Xi'an", "chn", 1906, "#33691E", "#FFD54F", "giant", "a xiezhi, a one-horned mythical beast", "defensive", 4, False),
    Club("east_asia", "Nanjing Nüwa", "Nüwa", "Nankín", "chn", 1919, "#00838F", "#FFB300", "charm", "the goddess Nüwa with a serpent tail mending the sky with coloured stones", "balanced", 2, False),
    Club("east_asia", "Seoul Samjogo", "Samjogo", "Seúl", "kor", 1904, "#212121", "#E53935", "sunray", "a three-legged crow inside a red sun", "speed", 6, True),
    Club("east_asia", "Busan Bulgasari", "Bulgasari", "Busan", "kor", 1916, "#455A64", "#FF8F00", "giant", "the bulgasari, an iron-eating monster", "resilient", 3, False),
    Club("east_asia", "Daegu Dokkaebi", "Dokkaebi", "Daegu", "kor", 1922, "#1B5E20", "#FFEB3B", "goblin", "a horned dokkaebi goblin swinging a magic club", "flamboyant", 2, False),
    Club("east_asia", "Incheon Imugi", "Imugi", "Incheon", "kor", 1928, "#1565C0", "#B3E5FC", "charm", "an imugi, a great serpent holding a pearl", "clever", 1, False),
    Club("low_countries", "Amsterdam Aalscholvers", "Aalscholvers", "Ámsterdam", "nld", 1879, "#C62828", "#FFFFFF", "kite_bird", "a cormorant diving over canal water", "attacking", 8, True),
    Club("low_countries", "Rotterdam Reigers", "Reigers", "Róterdam", "nld", 1888, "#212121", "#4FC3F7", "kite_bird", "a grey heron standing among reeds", "balanced", 5, True),
    Club("low_countries", "Den Haag Heksen", "Heksen", "La Haya", "nld", 1894, "#2E7D32", "#FFC107", "stick", "a witch on a broom over a windmill", "clever", 4, False),
    Club("low_countries", "Utrecht Uilen", "Uilen", "Utrecht", "nld", 1905, "#B71C1C", "#FFFFFF", "harrier_hawk", "a long-eared owl", "defensive", 2, False),
    Club("low_countries", "Groningen Griffioenen", "Griffioenen", "Groninga", "nld", 1912, "#1B5E20", "#FFFFFF", "harrier_hawk", "a griffin", "resilient", 1, False),
    Club("low_countries", "Antwerpen Arenden", "Arenden", "Amberes", "fla", 1882, "#0D47A1", "#FFFFFF", "harrier_hawk", "an eagle with spread wings", "attacking", 7, True),
    Club("low_countries", "Gent Gnomen", "Gnomen", "Gante", "fla", 1897, "#283593", "#FFEB3B", "goblin", "a garden gnome with a pointed hat", "flair", 3, False),
    Club("low_countries", "Brugge Beren", "Beren", "Brujas", "fla", 1890, "#4E342E", "#FFD54F", "", "a brown bear rearing", "aggressive", 4, False),
    Club("low_countries", "Leuven Leeuwen", "Leeuwen", "Lovaina", "fla", 1909, "#212121", "#FDD835", "", "a black lion rampant on gold", "balanced", 2, False),
    Club("eastern_europe", "Moskva Medvedi", "Medvedi", "Moscú", "rus", 1868, "#B71C1C", "#FFD54F", "", "a brown bear rearing with a broomstick", "aggressive", 6, True),
    Club("eastern_europe", "Sankt-Peterburg Sirini", "Sirini", "San Petersburgo", "rus", 1881, "#0D47A1", "#FFFFFF", "harrier_hawk", "Sirin, a mythical bird with a woman's head", "flair", 4, True),
    Club("eastern_europe", "Barnaul Baby-Yagi", "Baby-Yagi", "Barnaul", "rus", 1914, "#3E2723", "#FF8F00", "stick", "Baba Yaga flying in a mortar, steering with a pestle and sweeping with a broom", "clever", 1, False),
    Club("central_europe", "Praha Golemové", "Golemové", "Praga", "cze", 1868, "#7B1F1F", "#D4AF37", "giant", "the Golem of Prague, a clay giant with a glowing word on its forehead", "resilient", 8, True),
    Club("central_europe", "Brno Draci", "Draci", "Brno", "cze", 1879, "#C62828", "#FFFFFF", "charm", "the Brno dragon, a crocodile hanging from a town-hall arch", "aggressive", 5, True),
    Club("central_europe", "Plzeň Plivníci", "Plivníci", "Pilsen", "cze", 1894, "#FBC02D", "#212121", "meteor", "a plivník, a small fire-spitting forest creature", "flair", 3, False),
    Club("central_europe", "Olomouc Orli", "Orli", "Olomouc", "cze", 1902, "#1A237E", "#FFD54F", "harrier_hawk", "a black eagle with spread wings", "balanced", 2, False),
    Club("central_europe", "Bratislava Bludičky", "Bludičky", "Bratislava", "svk", 1897, "#0D47A1", "#B3E5FC", "star", "will-o'-the-wisp lights dancing over a marsh", "clever", 4, False),
    Club("central_europe", "Košice Kuvici", "Kuvici", "Košice", "svk", 1911, "#2E7D32", "#FFFFFF", "harrier_hawk", "a little owl", "defensive", 1, False),
    Club("central_europe", "Budapest Boszorkányok", "Boszorkányok", "Budapest", "hun", 1872, "#B71C1C", "#2E7D32", "stick", "a witch on a broom flying over the Danube bridges", "attacking", 9, True),
    Club("central_europe", "Debrecen Délibábok", "Délibábok", "Debrecen", "hun", 1906, "#F57C00", "#FFF3E0", "sunray", "a shimmering mirage over the Hungarian plain", "showmanship", 3, False),
    Club("central_europe", "Szeged Sárkányok", "Sárkányok", "Szeged", "hun", 1915, "#33691E", "#FFC107", "charm", "a many-headed Hungarian dragon", "aggressive", 2, False),
    Club("east_asia", "Bangkok Garudas", "Garudas", "Bangkok", "tha", 1910, "#B71C1C", "#FFD700", "harrier_hawk", "Garuda, a golden bird-man with spread wings", "flair", 4, True),
    Club("east_asia", "Chiang Mai Chang Phueak", "Chang Phueak", "Chiang Mai", "tha", 1926, "#4A148C", "#ECEFF1", "", "a white elephant under a temple roof", "resilient", 1, False),
]

RIVALRIES = [  # [FILLER]
    ("club_lagos_lightningbolts", "club_kano_kingfishers", "the league's two Nigerian clubs"),
    ("club_dakar_dune_dancers", "club_abidjan_antelopes", "the two French-speaking clubs of the West African coast"),
    ("club_cairo_crocodiles", "club_gimbi_giant_slayers", "the Nile derby: the league's most-titled club against the two-time All-Africa Cup winners from the Blue Nile highlands"),
    ("club_santiago_saetas", "club_valparaiso_vientos", "the Chilean derby: the capital against the port"),
    ("club_quito_quetzales", "club_guayaquil_guacamayos", "the Ecuadorian derby: the highland capital against the coast"),
    ("club_bogota_brujas", "club_medellin_mariposas", "the Colombian derby"),
    ("club_buenos_aires_buhos", "club_rosario_relampagos", "the league's two most successful clubs"),
    ("club_mar_del_plata_mareas", "club_bahia_blanca_ballenas", "the Atlantic coast derby"),
    ("club_cordoba_cometas", "club_mendoza_montaneses", "the derby of the interior, plains against mountains"),
    ("club_rio_redemoinhos", "club_sao_paulo_sacis", "the league's two most successful clubs"),
    ("club_recife_raposas", "club_salvador_sabias", "the north-east derby"),
    ("club_porto_alegre_pampeiros", "club_curitiba_curupiras", "the southern derby"),
    ("club_moose_jaw_meteorites", "club_stonewall_stormers", "the prairie derby, Saskatchewan against Manitoba"),
    ("club_haileybury_hammers", "club_trois_rivieres_tonnerres", "Ontario against Quebec; both clubs were founded in 1890"),
    ("club_vancouver_voyageurs", "club_calgary_coyotes", "the western derby across the Rockies"),
    ("club_praha_golemove", "club_brno_draci", "the Czech derby, Bohemia against Moravia"),
    ("club_bratislava_bludicky", "club_kosice_kuvici", "the Slovak derby"),
    ("club_budapest_boszorkanyok", "club_debrecen_delibabok", "the Hungarian derby, the capital against the Great Plain"),
    ("club_beijing_baihu", "club_shanghai_shenlong", "the league's two most successful clubs"),
    ("club_seoul_samjogo", "club_busan_bulgasari", "the Korean derby"),
    ("club_bangkok_garudas", "club_chiang_mai_chang_phueak", "the Thai derby"),
    ("club_moskva_medvedi", "club_sankt_peterburg_sirini", "the Russian derby, the two old capitals"),
    ("club_krakow_kruki", "club_wrocaw_wilki", "the southern Polish derby"),
    ("club_vilnius_vytis", "club_kaunas_kometos", "the Lithuanian derby"),
    ("club_paris_phenix", "club_marseille_mistrals", "the capital against the Mediterranean, the two most successful clubs after Quiberon"),
    ("club_bordeaux_busards", "club_toulouse_tarasques", "the Garonne derby"),
    ("club_berlin_blitze", "club_munchen_mondkalber", "north against south, the league's two most successful clubs"),
    ("club_wien_windhunde", "club_salzburg_salamander", "the Austrian derby"),
    ("club_madrid_manticoras", "club_barcelona_basiliscos", "the league's two most successful clubs"),
    ("club_lisboa_lobisomens", "club_porto_pegasos", "the Portuguese derby, Lisbon against the north"),
    ("club_bombay_bulbuls", "club_delhi_dholes", "the league's two most successful clubs"),
    ("club_madras_mongooses", "club_bangalore_banyans", "the southern derby"),
    ("club_roma_ruggenti", "club_milano_mangiafuoco", "the league's two most successful clubs"),
    ("club_napoli_nottole", "club_benevento_befane", "the Campania derby"),
    ("club_tokio_tatsu", "club_osaka_oni", "east against west, the two great cities"),
    ("club_toyohashi_tengu", "club_nagoya_namazu", "the Aichi derby"),
    ("club_amsterdam_aalscholvers", "club_rotterdam_reigers", "the Dutch derby"),
    ("club_gent_gnomen", "club_brugge_beren", "the Flemish derby"),
    ("club_la_habana_huracanes", "club_kingston_krakens", "the Caribbean derby"),
    ("club_veracruz_viboras", "club_oaxaca_ocelotes", "neighbours on the Gulf and in the southern mountains"),
    ("club_stockholm_stormar", "club_goteborg_gripar", "the Swedish derby"),
    ("club_oslo_ormer", "club_bergen_bjrner", "the Norwegian derby"),
    ("club_helsinki_haukat", "club_tampere_tontut", "the Finnish derby"),
    ("club_sydney_sundowners", "club_melbourne_mopokes", "the two great Australian cities"),
    ("club_new_york_nifflers", "club_boston_banshees", "the East Coast derby"),
    ("club_los_angeles_luminaries", "club_san_francisco_sea_serpents", "the Californian derby"),
    ("club_fitchburg_finches", "club_sweetwater_all_stars", "inferred from their 1926 US league Grand Final [FB]"),
]

LEVEL_TABLE = {1: (7000, 12000, 400, 3000), 2: (4500, 6000, 250, 1500), 3: (2500, 2500, 150, 600)}


ID_OVERRIDES = {"Tokyo Tatsu": "club_tokio_tatsu", "Kyoto Kitsune": "club_kioto_kitsune"}


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def rivals_of(cid):
    """[(other club id, basis)] for a club in RIVALRIES (both directions)."""
    return [(b, why) for a, b, why in RIVALRIES if a == cid] + [(a, why) for a, b, why in RIVALRIES if b == cid]


def apply_rivalries(club, names):
    """Writes a club's invented derbies into identity (rivalries, rivalries_source) and its notes [FILLER]."""
    rivals = rivals_of(club["id"])
    if not rivals:
        return
    ident = {}
    for k, v in club["identity"].items():
        if k == "rivalries_source":
            continue
        ident[k] = v
        if k == "rivalries":
            ident[k] = list(v) + [o for o, _ in rivals if o not in v]
            ident["rivalries_source"] = "filler"
    if "rivalries" not in ident:
        ident["rivalries"] = [o for o, _ in rivals]
        ident["rivalries_source"] = "filler"
    club["identity"] = ident
    for o, why in rivals:
        line = f"Rivalry with {names.get(o, o)} [FILLER]: invented for the game ({why})."
        if f"Rivalry with {names.get(o, o)}" not in club.get("notes", ""):
            club["notes"] = (club.get("notes", "") + " " + line).strip()


def main():
    comps = {}
    for f in os.listdir(f"{PACK}/competitions"):
        d = json.load(open(f"{PACK}/competitions/{f}"))
        comps[d["id"]] = (f, d)
    for f in os.listdir(f"{PACK}/clubs"):
        d = json.load(open(f"{PACK}/clubs/{f}"))
        if d.get("source") == "filler_authored":
            os.remove(f"{PACK}/clubs/{f}")
    names = {"club_" + slug(c.name): c.name for c in CLUBS}
    for f in os.listdir(f"{PACK}/clubs"):
        d = json.load(open(f"{PACK}/clubs/{f}"))
        names[d["id"]] = d["name"]
    added = {}
    seen = set()
    for c in CLUBS:
        cid = ID_OVERRIDES.get(c.name, "club_" + slug(c.name))
        assert cid not in seen, cid
        seen.add(cid)
        comp_id = f"comp_{c.league}_league"
        comp = comps[comp_id][1]
        level = min(comp["level"] + (0 if c.elite else 1), 3)
        rep, bal, wage, transfer = LEVEL_TABLE[level]
        rep += (c.titles * 120) - 300
        club = {
            "id": cid, "name": c.name, "short_name": c.short_name, "city": f"{c.city}, {COUNTRY[c.country]}", "country_id": c.country,
            "region_id": comp["region_id"], "founded": c.founded, "colors": {"primary": c.primary, "secondary": c.secondary},
            "emblem_key": c.emblem_key, "emblem_desc": c.emblem_desc,
            "identity": {"style_tags": [c.style], "motto": "", "rivalries": [], "fan_traits": [], "mascot": ""},
            "league_id": comp_id, "level": level, "reputation": rep,
            "finances": {"balance": bal, "wage_budget_weekly": wage, "transfer_budget": transfer},
            "facilities": {"training": 5 - level, "medical": 4 - level, "broom_workshop": max(3 - level, 1)},
            "constraints": {}, "manager_name": "",
            "history": {"league_titles": c.titles, "european_cups": 0, "notes_keys": []},
            "source": "filler_authored",
            "notes": "[FILLER] Club designed for the game (the books do not name it): name, city, colors, figure, founding year, titles and style.",
        }
        apply_rivalries(club, names)
        json.dump(club, open(f"{PACK}/clubs/{cid}.json", "w"), ensure_ascii=False, indent=2)
        added.setdefault(comp_id, []).append(cid)
    for cid in sorted({c for a, b, _ in RIVALRIES for c in (a, b)} - seen):
        path = f"{PACK}/clubs/{cid}.json"
        if os.path.exists(path):
            d = json.load(open(path))
            apply_rivalries(d, names)
            json.dump(d, open(path, "w"), ensure_ascii=False, indent=2)
    for comp_id, (fname, d) in comps.items():
        if d.get("type", "league") != "league":
            continue
        ids = [c for c in d["club_ids"] if not c.startswith("club_") or os.path.exists(f"{PACK}/clubs/{c}.json")]
        for c in added.get(comp_id, []):
            if c not in ids:
                ids.append(c)
        d["club_ids"] = ids
        d["filler_clubs"] = 0
        json.dump(d, open(f"{PACK}/competitions/{fname}", "w"), ensure_ascii=False, indent=2)
        print(f"{comp_id}: {len(ids)} clubs")
    print(f"{len(CLUBS)} clubs written")


if __name__ == "__main__":
    main()
