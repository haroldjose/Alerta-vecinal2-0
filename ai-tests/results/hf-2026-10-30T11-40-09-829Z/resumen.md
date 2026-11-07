# Resultados de las pruebas de IA (modo hf)

Fecha: 2026-10-30T11:40:09.829Z · Node v22.15.1
Modelos: toxicity: s-nlp/roberta_toxicity_classifier; type: joeddav/xlm-roberta-large-xnli; similarity: sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
Muestras: 40 de tipo, 44 de lenguaje y 30 pares de duplicados.

## Pruebas de API: estado y latencia

| API | Llamadas | HTTP 200 | Códigos HTTP | Media (ms) | P50 (ms) | P95 (ms) | Máx (ms) | Arranques en frío (503) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| toxicity | 44 | 100.0 % | 200×44 | 99 | 84 | 101 | 705 | 0 |
| type | 40 | 100.0 % | 200×40 | 1265 | 1222 | 1457 | 1988 | 0 |
| similarity | 30 | 100.0 % | 200×30 | 36 | 34 | 57 | 68 | 0 |

## Lenguaje ofensivo
Muestras: 22 ofensivas y 22 no ofensivas. Umbral de la función: 0.75.

| Método | Precisión | Exhaustividad | F1 | Exactitud | VP/FP/FN/VN |
| --- | --- | --- | --- | --- | --- |
| Solo lista local de palabras | 77.8 % | 63.6 % | 70.0 % | 72.7 % | 14/4/8/18 |
| Solo modelo de Hugging Face (umbral 0.75) | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| Combinado (como en checkOffensiveContent) | 78.9 % | 68.2 % | 73.2 % | 75.0 % | 15/4/7/18 |

Puntaje tóxico medio del modelo: ofensivos 0.098 / no ofensivos 0.004.
Ofensivos que solo detectó el modelo (la lista local no): 1 de 22. Falsos positivos de la lista local: 4 de 22.


**Variación del umbral del modelo (solo Hugging Face)**

| Método | Precisión | Exhaustividad | F1 | Exactitud | VP/FP/FN/VN |
| --- | --- | --- | --- | --- | --- |
| HF solo, umbral 0.3 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.5 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.6 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.7 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.75 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.8 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.9 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |
| HF solo, umbral 0.95 | 100.0 % | 9.1 % | 16.7 % | 54.5 % | 2/0/20/22 |

**Errores del método combinado**

| Tipo | ID | Texto | Lista local | Puntaje HF |
| --- | --- | --- | --- | --- |
| Falso negativo | O05 | Cállense de una vez, imbéciles, nadie quiere escuchar su música. | no | 0.007 |
| Falso negativo | O10 | Estos weones no respetan a nadie. | no | 0.000 |
| Falso negativo | O15 | Mal nacidos todos ustedes, ojalá se mueran. | no | 0.004 |
| Falso negativo | O16 | Que te pudras, desgraciado. | no | 0.004 |
| Falso negativo | O18 | Eres una porquería de persona, inservible. | no | 0.018 |
| Falso negativo | O21 | Qué id1ota el que estacionó ahí. | no | 0.000 |
| Falso negativo | O22 | Son unos p3ndejos, no respetan a nadie. | no | 0.008 |
| Falso positivo | L04 | Los animales abandonados en la calle necesitan ayuda, hay varios perr… | sí (animales) | 0.006 |
| Falso positivo | L05 | Hay un animal muerto en la acequia que provoca mal olor. | sí (animal) | 0.004 |
| Falso positivo | L06 | La basura acumulada da asco a todos los que pasan por el parque. | sí (asco) | 0.000 |
| Falso positivo | L07 | Qué bestia de bache, casi rompo la llanta. | sí (bestia) | 0.004 |

## Sugerencia de tipo de problema
Muestras: 40 (10 por categoría).

| Método | Exactitud | F1 macro |
| --- | --- | --- |
| Solo palabras clave (sin resultado cuenta como error) | 50.0 % | 58.9 % |
| Solo modelo zero-shot de Hugging Face | 62.5 % | 57.5 % |
| Combinado (como en suggestProblemType) | 77.5 % | 77.3 % |

**Combinado: resultado por fuente de la decisión**

| Fuente | Casos | Aciertos | Exactitud |
| --- | --- | --- | --- |
| IA | 22 | 16 | 72.7 % |
| palabras clave | 18 | 15 | 83.3 % |

El filtro de palabras clave resolvió 18 de 40 casos sin necesitar el modelo en la decisión final.

**Combinado: métricas por categoría**

| Categoría | Precisión | Exhaustividad | F1 |
| --- | --- | --- | --- |
| inseguridad | 75.0 % | 60.0 % | 66.7 % |
| serviciosBasicos | 69.2 % | 90.0 % | 78.3 % |
| contaminacion | 88.9 % | 80.0 % | 84.2 % |
| convivencia | 80.0 % | 80.0 % | 80.0 % |

**Combinado: matriz de confusión**

| Real \ Predicho | inseguridad | serviciosBasicos | contaminacion | convivencia | ninguna |
| --- | --- | --- | --- | --- | --- |
| inseguridad | 6 | 1 | 1 | 2 | 0 |
| serviciosBasicos | 1 | 9 | 0 | 0 | 0 |
| contaminacion | 0 | 2 | 8 | 0 | 0 |
| convivencia | 1 | 1 | 0 | 8 | 0 |

**Solo Hugging Face: matriz de confusión**

| Real \ Predicho | inseguridad | serviciosBasicos | contaminacion | convivencia | ninguna |
| --- | --- | --- | --- | --- | --- |
| inseguridad | 1 | 6 | 1 | 2 | 0 |
| serviciosBasicos | 0 | 7 | 2 | 1 | 0 |
| contaminacion | 0 | 1 | 9 | 0 | 0 |
| convivencia | 0 | 2 | 0 | 8 | 0 |

**Errores del método combinado**

| ID | Texto | Real | Predicho | Fuente | Puntaje HF |
| --- | --- | --- | --- | --- | --- |
| T01 | Intentaron robar en la tienda de la esquina. Rompieron el candado de … | inseguridad | convivencia | IA | 0.457 |
| T02 | Grupo de jóvenes consumiendo alcohol en la plaza y molestando a los q… | inseguridad | contaminacion | IA | 0.406 |
| T03 | Dos personas sospechosas rondando los autos estacionados en mi calle … | inseguridad | serviciosBasicos | IA | 0.513 |
| T07 | Un hombre desconocido sigue a las niñas que salen del colegio por la … | inseguridad | convivencia | IA | 0.574 |
| T17 | Hay un cable de alta tensión suelto cerca de la escuela, es muy pelig… | serviciosBasicos | inseguridad | palabras clave | 0.329 |
| T23 | Una fábrica vierte aceite y residuos en la acequia del barrio. | contaminacion | serviciosBasicos | IA | 0.844 |
| T29 | Echan agua sucia con químicos al desagüe de la calle y hay un olor fu… | contaminacion | serviciosBasicos | palabras clave | 0.825 |
| T35 | Los vecinos del edificio dejan sus bolsas en el pasillo común y no re… | convivencia | serviciosBasicos | IA | 0.851 |
| T38 | Hay una pelea entre vecinos por el uso del lavandero comunal. | convivencia | inseguridad | palabras clave | 0.670 |

## Detección de reportes duplicados
Pares: 15 duplicados y 15 no duplicados. Umbral de Jaccard: 0.1. Umbral de similitud semántica: 0.7.

| Método | Precisión | Exhaustividad | F1 | Exactitud | VP/FP/FN/VN |
| --- | --- | --- | --- | --- | --- |
| Solo filtro Jaccard (≥ 0.1) | 81.3 % | 86.7 % | 83.9 % | 83.3 % | 13/3/2/12 |
| Solo Jaccard (≥ 0,45, respaldo sin IA) | n/d | 0.0 % | n/d | 50.0 % | 0/0/15/15 |
| Solo modelo de Hugging Face (≥ 0.7) | 100.0 % | 53.3 % | 69.6 % | 76.7 % | 8/0/7/15 |
| Combinado (como en checkDuplicateReport) | 100.0 % | 53.3 % | 69.6 % | 76.7 % | 8/0/7/15 |

Similitud semántica media: duplicados 0.727 / no duplicados 0.338.
Jaccard medio: duplicados 0.208 / no duplicados 0.028.
Duplicados reales que pasan el filtro Jaccard: 13 de 15. Los demás no llegan nunca al modelo.

**Variación del umbral de similitud (solo Hugging Face)**

| Método | Precisión | Exhaustividad | F1 | Exactitud | VP/FP/FN/VN |
| --- | --- | --- | --- | --- | --- |
| HF solo, umbral 0.5 | 87.5 % | 93.3 % | 90.3 % | 90.0 % | 14/2/1/13 |
| HF solo, umbral 0.55 | 100.0 % | 93.3 % | 96.6 % | 96.7 % | 14/0/1/15 |
| HF solo, umbral 0.6 | 100.0 % | 93.3 % | 96.6 % | 96.7 % | 14/0/1/15 |
| HF solo, umbral 0.65 | 100.0 % | 60.0 % | 75.0 % | 80.0 % | 9/0/6/15 |
| HF solo, umbral 0.7 | 100.0 % | 53.3 % | 69.6 % | 76.7 % | 8/0/7/15 |
| HF solo, umbral 0.75 | 100.0 % | 46.7 % | 63.6 % | 73.3 % | 7/0/8/15 |
| HF solo, umbral 0.8 | 100.0 % | 46.7 % | 63.6 % | 73.3 % | 7/0/8/15 |
| HF solo, umbral 0.85 | 100.0 % | 26.7 % | 42.1 % | 63.3 % | 4/0/11/15 |
| HF solo, umbral 0.9 | 100.0 % | 6.7 % | 12.5 % | 53.3 % | 1/0/14/15 |

**Errores del método combinado**

| ID | Real | Texto A | Texto B | Jaccard | Similitud |
| --- | --- | --- | --- | --- | --- |
| D02 | duplicado | No hay agua potable en el barrio desde hace … | Llevamos 72 horas sin agua en la zona | 0.125 | 0.618 |
| D05 | duplicado | Queman llantas en el terreno baldío | Humo negro por quema de neumáticos en el lot… | 0.000 | 0.438 |
| D06 | duplicado | Fiesta ruidosa del vecino hasta la madrugada | El vecino hizo una fiesta con música muy alt… | 0.222 | 0.662 |
| D09 | duplicado | Semáforo dañado en el cruce de la avenida | El semáforo del cruce no funciona | 0.400 | 0.646 |
| D12 | duplicado | Auto bloqueando mi garaje | Hay un vehículo estacionado frente a mi entr… | 0.000 | 0.648 |
| D13 | duplicado | Asaltaron a una señora en la parada del micro | Le robaron la cartera a una mujer cuando esp… | 0.125 | 0.649 |
| D15 | duplicado | Fábrica vierte aceite en la acequia | Una industria tira residuos de aceite a la a… | 0.250 | 0.600 |
