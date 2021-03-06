include	<ctype.h>
include	<math/curfit.h>
include	<math/gsurfit.h>
include	"sky.h"
include	"skyfit.h"
include	"skyblock.h"
include	"detect.h"
include	"split.h"
include	"grow.h"
include	"evaluate.h"
include	"filter.h"



# SKY_PARS -- Sky parameters.

procedure sky_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp

int	strdic()
pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		return
	    call calloc (pars, SKY_LEN, TY_STRUCT)

	    pp = clopset (pset)
#	    call clgpseta (pp, "skytype", SKY_STR(pars), SKY_STRLEN)
#	    SKY_TYPE(pars) = strdic (SKY_STR(pars), SKY_STR(pars), SKY_STRLEN,
#		SKY_TYPES)
	    if (option[1] == 'a') {
		call clgpseta (pp, "skyotype", SKY_STR(pars), SKY_STRLEN)
		SKY_OTYPE(pars) = strdic (SKY_STR(pars), SKY_STR(pars),
		    SKY_STRLEN, SKY_OTYPES)
	    } else
		SKY_OTYPE(pars) = SKY_OSKY
	    call clcpset (pp)

	    call skb_pars (option, pset, SKY_SKB(pars))
	    if (SKY_SKB(pars) == NULL)
		SKY_TYPE(pars) = SKY_FIT
	    else
		SKY_TYPE(pars) = SKY_BLOCK
	case 't':
	    if (pars == NULL)
		return

	    pp = clopset (pset)
	    call clgpseta (pp, "skyotype", SKY_STR(pars), SKY_STRLEN)
	    SKY_OTYPE(pars) = strdic (SKY_STR(pars), SKY_STR(pars), SKY_STRLEN,
		SKY_OTYPES)
	    call clcpset (pp)
	case 'c':
	    if (pars != NULL) {
		call skf_pars ("close", "", SKY_SKF(pars))
		call skb_pars ("close", "", SKY_SKB(pars))
	    }
	    call mfree (pars, TY_STRUCT)
	}
end


# SKF_PARS -- Sky fit parameters.

procedure skf_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp

int	clgpseti(), strdic()
real	clgpsetr()
pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		return
	    call calloc (pars, SKF_LEN, TY_STRUCT)

	    pp = clopset (pset)

	    SKF_STEP(pars) = clgpsetr (pp, "fitstep")
	    SKF_BLK1D(pars) = clgpseti (pp, "fitblk1d")
	    SKF_HCLIP(pars) = clgpsetr (pp, "fithclip")
	    SKF_LCLIP(pars) = clgpsetr (pp, "fitlclip")
	    SKF_XORDER(pars) =  clgpseti (pp, "fitxorder")
	    SKF_YORDER(pars) =  clgpseti (pp, "fityorder")

	    SKF_LMIN(pars) = SKFLMIN
	    SKF_FUNC1D(pars) = strdic (SKFFUNC1D, SKF_STR(pars),
		SKF_STRLEN, CV_FUNCTIONS)
	    SKF_FUNC2D(pars) = strdic (SKFFUNC2D, SKF_STR(pars),
		SKF_STRLEN, GS_FUNCTIONS)
	    SKF_XTERMS(pars) = strdic (SKFXTERMS, SKF_STR(pars),
		SKF_STRLEN, GS_XTYPES) - 1
	    SKF_NITER(pars) = SKFNITER

	    call clcpset (pp)
	case 'c':
	    call mfree (pars, TY_STRUCT)
	}
end


# SKB_PARS -- Sky block parameters.

procedure skb_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp, cp
double	x, y, sum1, sum2

int	clgpseti()
pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		 return

	    call calloc (pars, SKB_LEN, TY_STRUCT)

	    pp = clopset (pset)
	    SKB_BLKSIZE(pars) = clgpseti (pp, "blksize")
	    SKB_BLKSTEP(pars) = clgpseti (pp, "blkstep")
	    SKB_NSUBBLKS(pars) = max (1, clgpseti (pp, "blknsubblks"))

	    call strcpy (SKBCNV, Memc[SKB_CNV(pars)], SKB_STRLEN)
	    SKB_SKYMIN(pars) = SKBSKYMIN
	    SKB_FRAC(pars) = SKBFRAC
	    SKB_GROW(pars) = SKBGROW
	    SKB_SIGBIN(pars) = SKBSIGBIN
	    SKB_NMINPIX(pars) = SKBNMINPIX
	    SKB_NMINBINS(pars) = SKBNMINBINS
	    SKB_HISTWT(pars) = SKBHISTWT
	    #SKB_HISTWT(pars) = 1
	    SKB_A(pars) = 1. / SKBA
	    #SKB_A(pars) = 1. / .05
	    SKB_NBINS(pars) = nint (2 * SKB_SIGBIN(pars) * SKB_A(pars))
	    SKB_NBINS(pars) = SKB_NBINS(pars) + mod (SKB_NBINS(pars)+1, 2)
	    SKB_B(pars) = SKB_NBINS(pars) / 2. + 1

	    for (cp=SKB_CNV(pars); IS_WHITE(Memc[cp]); cp=cp+1)
		;
	    call strcpy (Memc[cp], Memc[SKB_CNV(pars)], SKB_STRLEN)

	    # Compute sigma correction factor from mean absolute deviation.
	    sum1 = 0.
	    sum2 = 0.
	    for (x=-SKB_SIGBIN(pars); x<=SKB_SIGBIN(pars); x=x+0.01) {
		y = exp (-x*x/2.)
		sum1 = sum1 + abs(x)*y
		sum2 = sum2 + y
	    }
	    SKB_SIGFAC(pars) = sum2 / sum1

	    SKB_AVSKY(pars) = INDEFR
	    SKB_AVSIG(pars) = INDEFR

	    call clcpset (pp)

	    if (SKB_BLKSIZE(pars) == 0 || SKB_BLKSTEP(pars) == 0)
	        call mfree (pars, TY_STRUCT)
	case 'c':
	    call mfree (pars, TY_STRUCT)
	}
end


# DET_PARS -- Detect parameters.

procedure det_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp

int	i, j
pointer	sp, str, cp, ptr
bool	clgpsetb()
int	clgpseti(), btoi(), decode_ranges()
real	clgpsetr()
pointer	clopset()

errchk	calloc

int	nowhite()

begin
	call smark (sp)
	call salloc (str, SZ_LINE, TY_CHAR)

	switch (option[1]) {
	case 'a', 'o', 'd':
	    if (pars != NULL)
		return
	    call calloc (pars, DET_LEN, TY_STRUCT)

	    pp = clopset (pset)

	    # Default is all values.
	    call clgpseta (pp, "bpdetect", Memc[DET_CNV(pars)], DET_STRLEN)
	    if (decode_ranges (Memc[DET_CNV(pars)], DET_BPDET(pars), DET_NBP,
	        i) == ERR)
		call error (1, "Error parsing 'bpdetect' parameter")

	    # Default is no values.
	    call clgpseta (pp, "bpflag", Memc[DET_CNV(pars)], DET_STRLEN)
	    if (nowhite(Memc[DET_CNV(pars)],Memc[DET_CNV(pars)],DET_STRLEN)==0)
	        DET_BPFLG(pars) = INDEFI
	    else {
		if (decode_ranges(Memc[DET_CNV(pars)],DET_BPFLG(pars),DET_NBP,
		    i) == ERR)
		    call error (1, "Error parsing 'bpflag' parameter")
	    }

	    call clgpseta (pp, "convolve", Memc[DET_CNV(pars)], DET_STRLEN)
	    DET_HSIG(pars) = clgpsetr (pp, "hsigma")
	    DET_LSIG(pars) = clgpsetr (pp, "lsigma")
	    DET_HDETECT(pars) = btoi (clgpsetb (pp, "hdetect"))
	    DET_LDETECT(pars) = btoi (clgpsetb (pp, "ldetect"))
	    DET_NEIGHBORS(pars) = clgpseti (pp, "neighbors")
	    DET_MINPIX(pars) = clgpseti (pp, "minpix")
	    DET_SIGAVG(pars) = clgpsetr (pp, "sigavg")
	    DET_SIGPEAK(pars) = clgpsetr (pp, "sigmax")
	    DET_BPVAL(pars) = clgpseti (pp, "bpval")
	    if (clgpsetb (pp, "updatesky")) {
	        DET_UPDSKY(pars) = YES
		#call skb_pars ("open", pset, DET_SKB(pars))
	    } else
	        DET_UPDSKY(pars) = NO

	    # Check convolution kernel.
	    for (cp=DET_CNV(pars); IS_WHITE(Memc[cp]); cp=cp+1)
		;
	    call strcpy (Memc[cp], Memc[DET_CNV(pars)], DET_STRLEN)
	    if (Memc[DET_CNV(pars)] != EOS) {
		call cnvparse (Memc[DET_CNV(pars)], ptr, i, j,
		    DET_SCNV(pars), NULL, 0)
		call mfree (ptr, TY_REAL)
		if (i == 1 && j == 1) {
		    Memc[DET_CNV(pars)] = EOS
		    DET_SCNV(pars) = NO
		}
	    }

	    # The following are unique to diffdetect.
	    if (option[1] == 'a' || option[1] == 'd')
		DET_FRAC2(pars) = clgpsetr (pp, "rfrac")

	    call clcpset (pp)

	    if (DET_HDETECT(pars) == NO && DET_LDETECT(pars) == NO)
	        call mfree (pars, TY_STRUCT)
	case 'c':
	    if (pars != NULL)
		call skb_pars ("close", "", DET_SKB(pars))
	    call mfree (pars, TY_STRUCT)
	}
	
	call sfree (sp)
end


# SPT_PARS -- Split parameters.

procedure spt_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp

int	clgpseti()
real	clgpsetr()
pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		return
	    call calloc (pars, SPT_LEN, TY_STRUCT)

	    pp = clopset (pset)

	    SPT_NEIGHBORS(pars) = clgpseti (pp, "neighbors")
	    SPT_SPLITMAX(pars) = clgpsetr (pp, "splitmax")
	    SPT_SPLITSTEP(pars) = clgpsetr (pp, "splitstep")
	    SPT_SPLITTHRESH(pars) = clgpsetr (pp, "splitthresh")
	    SPT_MINPIX(pars) = clgpseti (pp, "minpix")
	    SPT_SIGAVG(pars) = clgpsetr (pp, "sigavg")
	    SPT_SIGPEAK(pars) = clgpsetr (pp, "sigmax")
	    SPT_SMINPIX(pars) = clgpseti (pp, "sminpix")
	    SPT_SSIGAVG(pars) = clgpsetr (pp, "ssigavg")
	    SPT_SSIGPEAK(pars) = clgpsetr (pp, "ssigmax")

	    call clcpset (pp)

	    if (SPT_SPLITSTEP(pars) <= 0.)
	        call mfree (pars, TY_STRUCT)
	case 'c':
	    call mfree (pars, TY_STRUCT)
	}

end


# GRW_PARS -- Grow parameters.

procedure grw_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp

int	clgpseti()
real	clgpsetr()
pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		return
	    call calloc (pars, GRW_LEN, TY_STRUCT)

	    pp = clopset (pset)
	    GRW_NGROW(pars) = clgpseti (pp, "ngrow")
	    GRW_AGROW(pars) = clgpsetr (pp, "agrow")
	    call clcpset (pp)

	    if (GRW_NGROW(pars) <= 0 && GRW_AGROW(pars) <= 0.)
	        call mfree (pars, TY_STRUCT)
	case 'c':
	    call mfree (pars, TY_STRUCT)
	}

end


# EVL_PARS -- Evaluate parameters.

procedure evl_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

int	i
real	magzero
pointer	pp

int	ctor(), nowhite()
real	clgetr()
pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		return
	    call calloc (pars, EVL_LEN, TY_STRUCT)

	    pp = clopset (pset)
	    call clgpseta (pp, "magzero", EVL_MAGZERO(pars,1), EVL_STRLEN)
	    if (nowhite(EVL_MAGZERO(pars,1),EVL_MAGZERO(pars,1),EVL_STRLEN)==0)
		call strcpy ("INDEF", EVL_MAGZERO(pars,1), EVL_STRLEN)
	    if (EVL_MAGZERO(pars,1) != '!') {
		i = 1
		if (ctor (EVL_MAGZERO(pars,1), i, magzero) == 0)
		    call error (1, "Magnitude zero point parameter syntax")
	    }
	    EVL_FWHM(pars) = clgetr ("fwhm")
	    EVL_CAFWHM(pars) = clgetr ("cafwhm")
	    EVL_GWTSIG(pars) = clgetr ("gwtsig")
	    EVL_GWTNSIG(pars) = clgetr ("gwtnsig")
	    call clgpseta (pp, "order", EVL_ORDER(pars,1), EVL_STRLEN)
	    call clcpset (pp)
	case 'c':
	    call mfree (pars, TY_STRUCT)
	}
end


# FLT_PARS -- Filter parameters.

procedure flt_pars (option, pset, pars)

char	option[ARB]		#I Option
char	pset[ARB]		#I Pset
pointer	pars			#U Parameter structure

pointer	pp

pointer	clopset()

errchk	calloc

begin
	switch (option[1]) {
	case 'a', 'o':
	    if (pars != NULL)
		return
	    call calloc (pars, FLT_LEN, TY_STRUCT)

	    pp = clopset (pset)
	    call clgpseta (pp, "catfilter", FLT_FILTER(pars), FLT_STRLEN)
	    call strcpy ("NUM", FLT_NUM(pars), FLT_NUMLEN)
	    call clcpset (pp)
	case 'c':
	    call mfree (pars, TY_STRUCT)
	}
end
