####################F###################################################################################
#                                       Biblioth�que OutilsMS.R
#
# Reunit diff�rents programmes applicables � la microsimulation.
# On suppose qu'on travaille sur une (ou des) populations (chacune) d�crite(s) par un ensemble de
# variables stock�es sous forme de vecteurs colonnes. La taille d'une population est la longueur 
# commune � l'ensemble de vecteurs qui la d�crivent.
#
# Les fonctions propos�es sont :
# A) Quelques utilitaires de base
# B) Des fonctions de cr�ation et manipulation de listes d'identifiants tir�s au sein de ces 
#    populations 
#
########################################################################################################


# A) UTILITAIRES DE BASE
#########################

# -> Taux de sondage par d�faut
taux_sondage <- 1/10000


# -> Fonction minmax:
#    Applique simultan�ment un plancher et un plafond � une variable, i.e. retourne plancher si elle
#    lui est inf�rieure, plafond si elle lui est sup�rieure, et la laisse inchang�e sinon. Le dernier
#    argument, optionnel, est une liste d'indices pour lesquels appliquer l'op�ration. Dans ce cas, la
#    valeur est � zero pour les autres points.

minmax <- function(x,plancher,plafond,liste=c())
{
  y <- rep(0,length(x)) 
  if  (length(liste)==0)    {liste    <- 1:length(x)}
  if  (length(plancher)==1) {plancher <- rep(plancher,length(x))}
  if  (length(plafond) ==1) {plafond  <- rep(plafond ,length(x))}
  for (i in liste)      {y[i]  <- min(plafond[i],max(x[i],plancher[i]))}
  return (y)
}  

# -> Fonction part:
# Tronque les valeurs d'un vecteur � la partie comprise entre des valeurs plancher et plafond, avec 
# la m�me possibilit� de filtrage que pour la fonction minmax.
#
# Exemple d'appel : 
# 
#    sal_tr2 <- part(salaire,PlafondSS,2*PlafondSS,which(statut=cadre))
#

part <- function(x,plancher,plafond,liste=c(1:length(x)))     #MODIF#25/09/12
{
  y <- rep(0,length(x)) 
  if  (length(plancher)==1) {plancher <- rep(plancher,length(x))}
  if  (length(plafond) ==1) {plafond  <- rep(plafond ,length(x))}
  for (i in liste)       {y[i]  <- min(plafond[i]-plancher[i],max(x[i]-plancher[i],0))}
  return (y)  
}

# -> Interpolation lin�aire
# affn <- function (x,noeud,val)
# {
#   if (x<noeud[1])
#   {
#     return (val[1])
#   }
#   else if (x>noeud[length(noeud)])
#   {
#     return (val[length(val)])
#   }
#   else
#   {
#     i <- 1
#     while (x>noeud[i+1])
#     {
#       i <- i+1
#     }
#     return ((val[i]*(noeud[i+1]-x)+val[i+1]*(x-noeud[i]))/(noeud[i+1]-noeud[i]))
#   }
# }
affn <- function (x,noeud,val)
{
  n <- length(noeud)
  if       (x<=noeud[1])  {return (val[1])}
  else if  (x>=noeud[n])  {return (val[n])}
  else  
  {
    i <- sum(noeud<x)
    return (((x-noeud[i])*val[i+1]+(noeud[i+1]-x)*val[i])/(noeud[i+1]-noeud[i]))
  }
}

# -> Tirage multinomial d'une valeur parmi celles du tableau val, avec le jeu de probas prob
# (plus adapt�e que la la fonction  rmultinom de R)
# Exemple d'appel : statut <- rmult (10,c(CodeNC,CodeCad,CodeFPA,CodeFPS,CodeInd,CodCho),
#                                       c(0.4,0.2,0.1,0.1,0.1,0.1))
rmult <- function (n,val,prob)
{
   x <- numeric(n)
   for (k in 2:length(prob))
   {
      prob[k] <- prob[k-1]+prob[k]
   }
   prob <- prob/prob[length(prob)]
   alea <- runif(n)
   for (i in 1:n)
   {
      k <- 1
      while (prob[k] < alea[i])
      {
         k <- k+1
      }
      x[i] <- val[k]
   }
   return (x)
}

# -> Arrondi al�atoire � l'un des deux entiers les plus proches
arr_alea <- function (x)
{
  return (floor(x)+rbinom(1,1,x-floor(x)))
}

# -> Fonction inflate : convertit le r�sultat d'un comptage sur �chantillon en un chiffre en population 
#    r�elle
inflate <- function (x)
{
  return (x/taux_sondage);
}

# -> Function deflate : ramene un effectif ou une masse en population reelle a un effectif ou une masse
#    sur l'echantillon, avec arrondi aleatoire
deflate <- function (x)
{
  return (arr_alea(x*taux_sondage))
}


# B) MANIPULATION DE LISTES D'INDIVIDUS
########################################

# -> Fonction "tirage"
#
# Tirage d'un sous-�chantillon selon un vecteur de probabilit�s d'inclusion "proba" dont la taille n
# correspond � la taille de la population de d�part.
#
# Exemples d'appel 
#   liste <- tirage(proba,cible="aucune"   )        # Tirage bernouillien (non contraint)
#   liste <- tirage(proba,cible="sommeprob")        # Tirage contraint � somme(proba) (d�faut)
#   liste <- tirage(proba,cible=100)                # Tirage contraint � valeur quelconque

tirage <- function (proba,cible="sommeprob") 
{
  
  # On met a zero les probas manquantes et on definit la liste des individus a risque
  proba[is.na(proba)] <- 0
  a_risque <- which(proba>0)
  
  # Si tirage calé sur cible, on commence par ajuster les probabilités
  if (is.numeric(cible))
  {
    if (cible <= sum(proba==1))         # Cas où cible < nb individus proba==1
                                        # (NB : inclut mécaniquement le cas cible=0)
    {
      proba[proba<1] <- 0
    }
    else if (cible > length(a_risque))  # Cas ou cible > nbre d'individus à risque
    {
      proba[proba>0] <- 1
    }
    else                                #  Cas général
    {
      k     <- c()
      coeff <- c()
      iter  <- 0
      repeat
      {
        iter <- iter+1  
        if      (iter==1) {coeff[iter] <- 1.5*cible/sum(proba[a_risque])}
        else if (iter==2) {coeff[iter] <- 0.5*cible/sum(proba[a_risque])}
        else   
        {  
          coeff[iter] <- (coeff[iter-2]*(k[iter-1]-cible)
                          +coeff[iter-1]*(cible-k[iter-2]))/
                            (k[iter-1]-k[iter-2])
        }
        if (coeff[iter]<0) {coeff[iter] <- 0.1*coeff[iter-1]}
        k[iter] <- sum(coeff[iter]*proba[a_risque]/(1+(coeff[iter]-1)*proba[a_risque]))
        if (abs(k[iter]/cible-1) < 0.0001) break
      }
      proba[a_risque] <- coeff[iter]*proba[a_risque]/(1+(coeff[iter]-1)*proba[a_risque])
    }
  }
  
  # Tirage
  if (cible == "aucune")
  {
    n    <- length(proba)
    alea <- runif(n)
    return (which(alea<proba))
  }
  else
  {
    a_risque <- permut(a_risque)
    U        <- runif(1)
    j        <- 0
    liste    <- c()
    for (i in a_risque) 
    {
      U <- U+proba[i]
      if (U>1)
      {
        j        <- j +1
        liste[j] <- i
        U        <- U-1
      }
    }
    return (liste)
  }  
}



##### Fonction Loglogistique
# Tirage d'une VA selon une loi LogLogistique de fonction de repartition
# z**a/(b+z**a) parametree par deux quelconques de ses quantiles, par
# exemple
# 
# $x=LogLogist(.25,2,.5,3)
# 
# tirera une VA a valeurs positives dont le premier quartile est a 2 et la
# mediane est a 3.
# 
# Si l'on ajoute un argument supplementaire, cet argument est pris comme valeur de l'alea par defaut.
# Sinon, un alea est tire selon une loi uniforme.   


LogLogist <- function (q1,v1,q2,v2,aux="NULL")
{
a <-(log(q1/(1-q1))- log(q2/(1-q2)))/(log(v1/v2))
b <- (v1^a)*(1-q1)/q1 
if (aux=="NULL") {aux<-runif(1)}
return ( (b*aux/(1-aux))^(1/a))
}


# -> Fonction "tri"
#
# Tri d'une liste d'identifiants selon valeurs d'une variable. Par d�faut le tri est par valeurs
# croissantes mais on peut sp�cifier l'option type="decroissant'.
#
# Exemples d'appel
#   liste <- tri(liste, salaire)
#   liste <- tri(liste, salaire, type="decroissant")
#
tri <- function (liste,var,type="croissant") 
{
	n <- length(liste)
	tab <- matrix(nrow=n,ncol=2)
	tab[,1]<-liste
	tab[,2]<-var[liste]
  if (type == "croissant")   
  {
	  return (tab[order(tab[,2]),1])
  }
  else 
  {
    return (tab[rev(order(tab[,2])),1])
  }
}

# -> fonction "permut"
#
# Permutation al�atoire des �l�ments d'une liste
# Exemple d'appel
#
#   liste <- permut(liste)
#
permut <- function (liste) 
{
  n <- length(liste)
  for (i in 1:n)
  {
    j <- min(n,floor(i+runif(1)*(n+1-i)))
    buf      <- liste[i]
    liste[i] <- liste[j]
    liste[j] <- buf
  }
  return (liste)
}

# -> fonction sel
# S�lectionne les �l�ments d'une liste � ses premiers �l�ments ou aux �l�ments remplissant un
# crit�re donn�.
#
# Exemples d'appel:
#
#  liste <- sel(liste,10)       # S�lectionne les 10 premiers �l�ments de la liste
#  liste <- sel(liste,-10)      # Elimine les 10 premiers �l�ments de la liste
#  liste <- sel(liste,keep=x>2) # Ne retient que les i tels que x[i]>2
#  liste <- sel(liste,drop=x>2) # Elimine de la liste les �l�ments tels que x[i]>2

sel <- function(liste,n=0,keep=c(),drop=c())
{
  if (n>0)
  {
    return (liste[1:min(n,length(liste))])
  }
  else if (n<=(-length(liste)))
  {
    return (c())
  }
  else if (n<0)
  {
    return (liste[(1-n):length(liste)])
  }
  else if (length(keep)>0)
  {
    return (intersect(liste,which(keep)))
  }
  else if (length(drop)>0)
  {
    return (setdiff(liste,which(drop)))
  }  
}


# -> fonction shift
# equivalent de la fonction de meme nom en perl. Réduit la liste en extrayant son 
# premier élément et retourne la valeur de celui-ci
#
# Exemples d'appel
#
#  i <- shift(liste)

shift <- function(liste)
{
  return (liste[1])
}


# -> fonction taux
taux <- function(filtre1,filtre2)
{
  denom <- sum(filtre2)
  if (denom>0) {return(sum(filtre1 & filtre2)/denom)}
}

